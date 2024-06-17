# frozen_string_literal: true

module Appsignal
  module Rack
    APPSIGNAL_TRANSACTION = "appsignal.transaction"
    RACK_AFTER_REPLY = "rack.after_reply"

    class EventHandler
      include ::Rack::Events::Abstract

      def self.safe_execution(name)
        yield
      rescue => e
        Appsignal.internal_logger.error(
          "Error occurred in #{name}: #{e.class}: #{e}: #{e.backtrace}"
        )
      end

      def on_start(request, _response)
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_start") do
          transaction = Appsignal::Transaction.create(
            SecureRandom.uuid,
            Appsignal::Transaction::HTTP_REQUEST,
            request
          )
          request.env[APPSIGNAL_TRANSACTION] = transaction

          request.env[RACK_AFTER_REPLY] ||= []
          request.env[RACK_AFTER_REPLY] << proc do
            Appsignal::Rack::EventHandler
              .safe_execution("Appsignal::Rack::EventHandler's after_reply") do
              transaction.finish_event("process_request.rack", "", "")
              transaction.set_http_or_background_queue_start

              # Make sure the current transaction is always closed when the request
              # is finished. This is a fallback for in case the `on_finish`
              # callback is not called. This is supported by servers like Puma and
              # Unicorn.
              #
              # The EventHandler.on_finish callback should be called first, this is
              # just a fallback if that doesn't get called.
              Appsignal::Transaction.complete_current!
            end
          end
          transaction.start_event
        end
      end

      def on_error(request, _response, error)
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_error") do
          transaction = request.env[APPSIGNAL_TRANSACTION]
          return unless transaction

          transaction.set_error(error)
        end
      end

      def on_finish(request, response)
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_finish") do
          transaction = request.env[APPSIGNAL_TRANSACTION]
          return unless transaction

          transaction.finish_event("process_request.rack", "", "")
          transaction.set_tags(:response_status => response.status)
          transaction.set_http_or_background_queue_start
          Appsignal.increment_counter(
            :response_status,
            1,
            :status => response.status,
            :namespace => format_namespace(transaction.namespace)
          )

          # Make sure the current transaction is always closed when the request
          # is finished
          Appsignal::Transaction.complete_current!
        end
      end

      private

      def format_namespace(namespace)
        if namespace == Appsignal::Transaction::HTTP_REQUEST
          :web
        else
          namespace
        end
      end
    end
  end
end
