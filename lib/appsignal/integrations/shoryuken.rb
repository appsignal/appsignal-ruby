# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    class ShoryukenMiddleware
      def call(worker_instance, queue, sqs_msg, body, &block)
        transaction = Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)

        Appsignal.instrument("perform_job.shoryuken", &block)
      rescue Exception => error # rubocop:disable Lint/RescueException
        transaction.set_error(error)
        raise
      ensure
        batch = sqs_msg.is_a?(Array)
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
  end
end
