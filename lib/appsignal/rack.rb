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
  end
end
