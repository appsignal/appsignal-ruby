# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    #
    # Reads and writes W3C trace context the way OpenTelemetry's aws-sdk
    # instrumentation does: as SQS message attributes, using the global
    # propagator. Staying wire-equivalent means that if both AppSignal and
    # OpenTelemetry's aws-sdk instrumentation are active, one simply shadows the
    # other rather than corrupting the carrier. Collector mode only.
    module ShoryukenTraceContext
      module_function

      # SQS allows at most 10 message attributes per message. Mirror
      # OpenTelemetry and skip propagation rather than risk the enqueue failing
      # when the user already fills the slots.
      MAX_MESSAGE_ATTRIBUTES = 10

      # Writes each trace header as an SQS message attribute, matching the shape
      # OpenTelemetry's aws-sdk instrumentation injects on send.
      module MessageAttributeSetter
        def self.set(carrier, key, value)
          return if carrier.length >= MAX_MESSAGE_ATTRIBUTES

          carrier[key] = { :string_value => value, :data_type => "String" }
        end
      end

      # Reads a trace header back out of a message attribute. Works both for the
      # plain hash we inject and for the `Aws::SQS::Types::MessageAttributeValue`
      # struct delivered on receive, since both respond to `[:string_value]` /
      # `[:data_type]`.
      module MessageAttributeGetter
        def self.get(carrier, key)
          attribute = carrier[key]
          attribute[:string_value] if attribute && attribute[:data_type] == "String"
        end
      end

      # Read the incoming context off a message's SQS message attributes so the
      # transaction links back to the enqueuer. Returns an
      # `OpenTelemetry::Context`, or `nil` outside collector mode.
      def extract(message_attributes)
        Appsignal::OpenTelemetry.if_started do
          ::OpenTelemetry.propagation.extract(
            message_attributes || {},
            :getter => MessageAttributeGetter
          )
        end
      end

      # Write the current trace context into the outgoing send `options`.
      # Injects into a scratch carrier first and merges it into the message
      # attributes only when something was written, so an enqueue with no active
      # span (no transaction, or outside collector mode) leaves the options
      # untouched -- a transparent pass-through.
      def inject(options)
        Appsignal::OpenTelemetry.if_started do
          carrier = {}
          ::OpenTelemetry.propagation.inject(carrier, :setter => MessageAttributeSetter)
          next if carrier.empty?

          options[:message_attributes] = (options[:message_attributes] || {}).merge(carrier)
        end
      end
    end

    # @!visibility private
    class ShoryukenMiddleware
      def call(worker_instance, queue, sqs_msg, body, &block)
        batch = sqs_msg.is_a?(Array)

        # Read the incoming trace context off the message so the transaction
        # links back to the enqueuer. A batch carries messages from multiple
        # traces with no single parent, so only single messages link back.
        # No-op outside collector mode.
        context = ShoryukenTraceContext.extract(sqs_msg.message_attributes) unless batch

        transaction = Appsignal::Transaction.create(
          Appsignal::Transaction::BACKGROUND_JOB,
          :opentelemetry_context => context,
          :opentelemetry_scope => ["appsignal-ruby-shoryuken", Appsignal::VERSION]
        )

        Appsignal.instrument(
          "perform_job.shoryuken",
          :opentelemetry_scope => ["appsignal-ruby-shoryuken", Appsignal::VERSION],
          &block
        )
      rescue Exception => error
        transaction.set_error(error)
        raise
      ensure
        attributes = fetch_attributes(batch, sqs_msg)
        transaction.set_action_if_nil("#{worker_instance.class.name}#perform")
        transaction.add_params_if_nil { fetch_args(batch, sqs_msg, body) }
        transaction.add_tags(attributes)
        transaction.add_tags("queue" => queue)
        transaction.add_tags("batch" => true) if batch

        if attributes.key?("SentTimestamp")
          transaction.set_queue_start(Time.at(attributes["SentTimestamp"].to_i).to_i)
        end

        Appsignal::Transaction.complete_current!
      end

      private

      def fetch_attributes(batch, sqs_msg)
        if batch
          # We can't instrument batched message separately, the `yield` will
          # perform all the batched messages.
          # To provide somewhat useful metadata, Get first message based on
          # SentTimestamp, and use its attributes as metadata for the
          # transaction. We can't combine them all because then they would
          # overwrite each other and the last message (in an sorted order)
          # would be used as the source of the metadata.  With the
          # oldest/first message at least some useful information is stored
          # such as the first received time and the number of retries for the
          # first message. The newer message should have lower values and
          # timestamps in their metadata.
          first_msg =
            sqs_msg.min do |a, b|
              a.attributes["SentTimestamp"].to_i <=> b.attributes["SentTimestamp"].to_i
            end
          first_msg.attributes
        else
          sqs_msg.attributes.merge(:message_id => sqs_msg.message_id)
        end
      end

      def fetch_args(batch, sqs_msg, body)
        if batch
          bodies = {}
          sqs_msg.each_with_index do |msg, index|
            # Store all separate bodies on a hash with the key being the
            # message_id
            bodies[msg.message_id] = body[index]
          end
          bodies
        else
          case body
          when Hash
            body
          else
            { :params => body }
          end
        end
      end
    end

    # Shoryuken client middleware that records an `enqueue.shoryuken` event so
    # the enqueue shows up under the active transaction (both modes), and in
    # collector mode writes the current trace context onto the outgoing message
    # so the job that later performs links back to it.
    #
    # Like all AppSignal events, this only records when there's an active
    # transaction (e.g. enqueuing from within a web request or another job). An
    # enqueue with no transaction is a transparent pass-through.
    #
    # @!visibility private
    class ShoryukenClientMiddleware
      def call(options)
        # Under Active Job the enqueue is already recorded as an
        # `enqueue.active_job` event, so skip recording it again here. The trace
        # context is still injected so the performed job links back.
        if Appsignal::Transaction.current? &&
            Appsignal::Transaction.current.job_enqueue_events_suppressed?
          ShoryukenTraceContext.inject(options)
          return yield
        end

        Appsignal.instrument(
          "enqueue.shoryuken",
          enqueue_title(options),
          :opentelemetry_kind => :producer,
          :opentelemetry_scope => ["appsignal-ruby-shoryuken", Appsignal::VERSION]
        ) do
          ShoryukenTraceContext.inject(options)
          yield
        end
      end

      private

      # Enqueues through a Shoryuken worker carry the worker class in the
      # `shoryuken_class` message attribute. Raw `send_message` enqueues don't,
      # so there's no worker class to name -- fall back to the queue instead.
      def enqueue_title(options)
        worker_class = options.dig(:message_attributes, "shoryuken_class", :string_value)
        return "enqueue #{worker_class} job" if worker_class

        queue = options[:queue_url].to_s.split("/").last
        "enqueue on #{queue}"
      end
    end
  end
end
