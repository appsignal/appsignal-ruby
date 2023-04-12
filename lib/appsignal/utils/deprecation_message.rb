# frozen_string_literal: true

module Appsignal
  module Utils
    module DeprecationMessage
      def self.message(message, logger = Appsignal.logger)
        Kernel.warn "appsignal WARNING: #{message}"
        logger.warn message
      end

      def deprecation_message(message, logger = Appsignal.logger)
        Appsignal::Utils::DeprecationMessage.message(message, logger)
      end
    end
  end
end
