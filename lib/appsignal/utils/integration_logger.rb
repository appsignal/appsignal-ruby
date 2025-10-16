# frozen_string_literal: true

module Appsignal
  module Utils
    class IntegrationLogger < ::Logger
      MAX_MESSAGE_LENGTH = 2_000

      def add(severity, message = nil, progname = nil)
        if message.nil? && !block_given?
          # When called as logger.error("msg"), the message is in progname
          progname = truncate_message(progname)
        elsif message
          message = truncate_message(message)
        elsif block_given?
          message = truncate_message(yield)
        end
        super
      end

      private

      def truncate_message(message)
        return message unless message.is_a?(String)

        if message.length > MAX_MESSAGE_LENGTH
          "#{message[0, MAX_MESSAGE_LENGTH]}..."
        else
          message
        end
      end
    end
  end
end
