# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    module StdoutAndLoggerMessage
      def self.warning(message, logger = Appsignal.internal_logger)
        Kernel.warn "appsignal WARNING: #{message}"
        logger.warn message
      end

      def stdout_and_logger_warning(message, logger = Appsignal.internal_logger)
        Appsignal::Utils::StdoutAndLoggerMessage.warning(message, logger)
      end
    end
  end
end
