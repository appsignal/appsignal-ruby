# frozen_string_literal: true

module Appsignal
  module Utils
    # Subclass of logger with method to only log a warning once
    # prevents the local log from filling up with repeated messages.
    class IntegrationLogger < ::Logger
      def seen_keys
        @seen_keys ||= Set.new
      end

      def warn_once_then_debug(key, message)
        if seen_keys.add?(key).nil?
          debug message
        else
          warn message
        end
      end
    end
  end
end
