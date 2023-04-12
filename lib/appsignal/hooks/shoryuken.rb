# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ShoryukenMiddleware
      def call(worker_instance, queue, sqs_msg, body, &block)
        batch = sqs_msg.is_a?(Array)
        attributes =
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
            first_msg = sqs_msg.min do |a, b|
              a.attributes["SentTimestamp"].to_i <=> b.attributes["SentTimestamp"].to_i
            end
            # Add batch => true metadata so people can recognize when a
            # transaction is about a batch of messages.
            first_msg.attributes.merge(:batch => true)
          else
            sqs_msg.attributes.merge(:message_id => sqs_msg.message_id)
          end
        metadata = { :queue => queue }.merge(attributes)
        options = {
          :class => worker_instance.class.name,
          :method => "perform",
          :metadata => metadata
        }

        args =
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
        options[:params] = Appsignal::Utils::HashSanitizer.sanitize(
          args,
          Appsignal.config[:filter_parameters]
        )

        if attributes.key?("SentTimestamp")
          options[:queue_start] = Time.at(attributes["SentTimestamp"].to_i / 1000)
        end

        Appsignal.monitor_transaction("perform_job.shoryuken", options, &block)
      end
    end

    class ShoryukenHook < Appsignal::Hooks::Hook
      register :shoryuken

      def dependencies_present?
        defined?(::Shoryuken)
      end

      def install
        ::Shoryuken.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Appsignal::Hooks::ShoryukenMiddleware
          end
        end
      end
    end
  end
end
