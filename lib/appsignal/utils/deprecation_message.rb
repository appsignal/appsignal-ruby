module Appsignal
  module Utils
    module DeprecationMessage
      def deprecation_message(message, logger = Appsignal.logger)
        $stderr.puts "appsignal WARNING: #{message}"
        logger.warn message
      end
    end
  end
end
