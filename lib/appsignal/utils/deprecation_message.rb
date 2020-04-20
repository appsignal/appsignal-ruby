module Appsignal
  module Utils
    module DeprecationMessage
      def deprecation_message(message, logger = Appsignal.logger)
        $stdout.puts "appsignal WARNING: #{message}"
        logger.warn message
      end
    end
  end
end
