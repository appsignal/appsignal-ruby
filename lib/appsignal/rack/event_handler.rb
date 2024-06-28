# frozen_string_literal: true

module Appsignal
  module Rack
    APPSIGNAL_TRANSACTION = "appsignal.transaction"
    APPSIGNAL_EVENT_HANDLER_ID = "appsignal.event_handler_id"
    APPSIGNAL_EVENT_HANDLER_HAS_ERROR = "appsignal.event_handler.error"
    RACK_AFTER_REPLY = "rack.after_reply"

    # @api private
    class EventHandler
      include ::Rack::Events::Abstract

      def self.safe_execution(name)
        yield
      rescue => e
        Appsignal.internal_logger.error(
          "Error occurred in #{name}: #{e.class}: #{e}: #{e.backtrace}"
        )
      end

      attr_reader :id

      def initialize
        @id = SecureRandom.uuid
      end

      def request_handler?(given_id)
        id == given_id
      end

      def on_start(request, _response)
        event_handler = self
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_start") do
          request.env[APPSIGNAL_EVENT_HANDLER_ID] ||= id
          return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

          transaction = Appsignal::Transaction.create(
            SecureRandom.uuid,
            Appsignal::Transaction::HTTP_REQUEST,
            request
          )
          request.env[APPSIGNAL_TRANSACTION] = transaction

          request.env[RACK_AFTER_REPLY] ||= []
          request.env[RACK_AFTER_REPLY] << proc do
            next unless event_handler.request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

            Appsignal::Rack::EventHandler
              .safe_execution("Appsignal::Rack::EventHandler's after_reply") do
              transaction.finish_event("process_request.rack", "", "")
              transaction.set_http_or_background_queue_start
            end

            # Make sure the current transaction is always closed when the request
            # is finished. This is a fallback for in case the `on_finish`
            # callback is not called. This is supported by servers like Puma and
            # Unicorn.
            #
            # The EventHandler.on_finish callback should be called first, this is
            # just a fallback if that doesn't get called.
            Appsignal::Transaction.complete_current!
          end
          transaction.start_event
        end
      end

      def on_error(request, _response, error)
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_error") do
          return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

          transaction = request.env[APPSIGNAL_TRANSACTION]
          return unless transaction

          request.env[APPSIGNAL_EVENT_HANDLER_HAS_ERROR] = true
          transaction.set_error(error)
        end
      end

      def on_finish(request, response)
        return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

        transaction = request.env[APPSIGNAL_TRANSACTION]
        return unless transaction

        self.class.safe_execution("Appsignal::Rack::EventHandler#on_finish") do
          transaction.finish_event("process_request.rack", "", "")
          transaction.set_http_or_background_queue_start
          response_status =
            if response
              response.status
            elsif request.env[APPSIGNAL_EVENT_HANDLER_HAS_ERROR] == true
              500
            end
          if response_status
            transaction.set_tags(:response_status => response_status)
            Appsignal.increment_counter(
              :response_status,
              1,
              :status => response_status,
              :namespace => format_namespace(transaction.namespace)
            )
          end
        end

        # Make sure the current transaction is always closed when the request
        # is finished
        Appsignal::Transaction.complete_current!
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
