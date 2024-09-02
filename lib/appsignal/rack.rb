# frozen_string_literal: true

module Appsignal
  # @api private
  module Rack
    APPSIGNAL_TRANSACTION = "appsignal.transaction"
    APPSIGNAL_EVENT_HANDLER_ID = "appsignal.event_handler_id"
    APPSIGNAL_EVENT_HANDLER_HAS_ERROR = "appsignal.event_handler.error"
    APPSIGNAL_RESPONSE_INSTRUMENTED = "appsignal.response_instrumentation_active"
    RACK_AFTER_REPLY = "rack.after_reply"

    class Utils
      # Fetch the queue start time from the request environment.
      #
      # @since 3.11.0
      # @param env [Hash] Request environment hash.
      # @return [Integer, NilClass]
      def self.queue_start_from(env)
        return unless env

        env_var = env["HTTP_X_QUEUE_START"] || env["HTTP_X_REQUEST_START"]
        return unless env_var

        cleaned_value = env_var.tr("^0-9", "")
        return if cleaned_value.empty?

        value = cleaned_value.to_i
        if value > 4_102_441_200_000
          # Value is in microseconds. Transform to milliseconds.
          value / 1_000
        elsif value < 946_681_200_000
          # Value is too low to be plausible
          nil
        else
          # Value is in milliseconds
          value
        end
      end
    end

    class ApplyRackRequest
      attr_reader :request, :options

      def initialize(request, options = {})
        @request = request
        @options = options
        @params_method = options.fetch(:params_method, :params)
      end

      def apply_to(transaction)
        request_path = request.path
        transaction.set_metadata("request_path", request_path)
        # TODO: Remove in next major/minor version
        transaction.set_metadata("path", request_path)

        request_method = request_method_for(request)
        if request_method
          transaction.set_metadata("request_method", request_method)
          # TODO: Remove in next major/minor version
          transaction.set_metadata("method", request_method)
        end

        transaction.add_params { params_for(request) }
        transaction.add_session_data { session_data_for(request) }
        transaction.add_headers do
          request.env if request.respond_to?(:env)
        end

        queue_start = Appsignal::Rack::Utils.queue_start_from(request.env)
        transaction.set_queue_start(queue_start) if queue_start
      end

      private

      def params_for(request)
        return if !@params_method || !request.respond_to?(@params_method)

        request.send(@params_method)
      rescue => error
        Appsignal.internal_logger.error(
          "Exception while fetching params from '#{request.class}##{@params_method}': " \
            "#{error.class} #{error}"
        )
        nil
      end

      def request_method_for(request)
        request.request_method
      rescue => error
        Appsignal.internal_logger.error(
          "Exception while fetching the HTTP request method: #{error.class}: #{error}"
        )
        nil
      end

      def session_data_for(request)
        return unless request.respond_to?(:session)

        request.session.to_h
      rescue => error
        Appsignal.internal_logger.error(
          "Exception while fetching session data from '#{request.class}': " \
            "#{error.class} #{error}"
        )
        nil
      end
    end
  end
end
