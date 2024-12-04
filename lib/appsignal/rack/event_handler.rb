# frozen_string_literal: true

module Appsignal
  module Rack
    # Instrumentation middleware using Rack's Events module.
    #
    # We recommend using this in combination with the
    # {InstrumentationMiddleware}.
    #
    # This middleware will report the response status code as the
    # `response_status` tag on the sample. It will also report the response
    # status as the `response_status` metric.
    #
    # This middleware will ensure the AppSignal transaction is always completed
    # for every request.
    #
    # @example Add EventHandler to a Rack app
    #   # Add this middleware as the first middleware of an app
    #   use ::Rack::Events, [Appsignal::Rack::EventHandler.new]
    #
    #   # Then add the InstrumentationMiddleware
    #   use Appsignal::Rack::InstrumentationMiddleware
    #
    # @see https://docs.appsignal.com/ruby/integrations/rack.html
    #   Rack integration documentation.
    # @api public
    class EventHandler
      include ::Rack::Events::Abstract

      # @api private
      def self.safe_execution(name)
        yield
      rescue => e
        Appsignal.internal_logger.error(
          "Error occurred in #{name}: #{e.class}: #{e}: #{e.backtrace}"
        )
      end

      # @api private
      attr_reader :id

      # @api private
      def initialize
        @id = SecureRandom.uuid
      end

      # @api private
      def request_handler?(given_id)
        id == given_id
      end

      # @api private
      def on_start(request, _response)
        return unless Appsignal.active?

        event_handler = self
        self.class.safe_execution("Appsignal::Rack::EventHandler#on_start") do
          request.env[APPSIGNAL_EVENT_HANDLER_ID] ||= id
          return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

          transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
          transaction.start_event
          request.env[APPSIGNAL_TRANSACTION] = transaction

          request.env[RACK_AFTER_REPLY] ||= []
          request.env[RACK_AFTER_REPLY] << proc do
            next unless event_handler.request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

            Appsignal::Rack::EventHandler
              .safe_execution("Appsignal::Rack::EventHandler's after_reply") do
              transaction.finish_event("process_request.rack", "", "")
              queue_start = Appsignal::Rack::Utils.queue_start_from(request.env)
              transaction.set_queue_start(queue_start) if queue_start
            end

            # Make sure the current transaction is always closed when the request
            # is finished. This is a fallback for in case the `on_finish`
            # callback is not called. This is supported by servers like Puma and
            # Unicorn.
            #
            # The EventHandler.on_finish callback should be called first, this is
            # just a fallback if that doesn't get called.
            #
            # One such scenario is when a Puma "lowlevel_error" occurs.
            Appsignal::Transaction.complete_current!
          end
        end
      end

      # @api private
      def on_error(request, _response, error)
        return unless Appsignal.active?

        self.class.safe_execution("Appsignal::Rack::EventHandler#on_error") do
          return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

          transaction = request.env[APPSIGNAL_TRANSACTION]
          return unless transaction

          request.env[APPSIGNAL_EVENT_HANDLER_HAS_ERROR] = true
          transaction.set_error(error)
        end
      end

      # @api private
      def on_finish(request, response)
        return unless Appsignal.active?
        return unless request_handler?(request.env[APPSIGNAL_EVENT_HANDLER_ID])

        transaction = request.env[APPSIGNAL_TRANSACTION]
        return unless transaction

        self.class.safe_execution("Appsignal::Rack::EventHandler#on_finish") do
          transaction.finish_event("process_request.rack", "", "")
          transaction.add_params_if_nil { request.params }
          transaction.add_headers_if_nil { request.env }
          transaction.add_session_data_if_nil do
            request.session if request.respond_to?(:session)
          end
          queue_start = Appsignal::Rack::Utils.queue_start_from(request.env)
          transaction.set_queue_start(queue_start) if queue_start
          response_status =
            if response
              response.status
            elsif request.env[APPSIGNAL_EVENT_HANDLER_HAS_ERROR] == true
              500
            end
          if response_status
            transaction.add_tags(:response_status => response_status)
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
