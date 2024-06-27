# frozen_string_literal: true

require "logger"

module Appsignal
  module Utils
    # @api private
    class IntegrationMemoryLogger
      LEVELS = {
        Logger::DEBUG => :DEBUG,
        Logger::INFO => :INFO,
        Logger::WARN => :WARN,
        Logger::ERROR => :ERROR,
        Logger::FATAL => :FATAL,
        Logger::UNKNOWN => :UNKNOWN
      }.freeze

      attr_accessor :formatter, :level

      def add(severity, message, _progname = nil)
        message = formatter.call(severity, Time.now, nil, message) if formatter
        messages[severity] << message
      end
      alias log add

      def debug(message)
        add(:DEBUG, message)
      end

      def info(message)
        add(:INFO, message)
      end

      def warn(message)
        add(:WARN, message)
      end

      def error(message)
        add(:ERROR, message)
      end

      def fatal(message)
        add(:FATAL, message)
      end

      def unknown(message)
        add(:UNKNOWN, message)
      end

      def clear
        messages.clear
      end

      def messages
        @messages ||= Hash.new { |hash, key| hash[key] = [] }
      end

      def messages_for_level(level)
        levels = LEVELS.select { |log_level| log_level >= level }.values
        messages
          .select { |log_level| levels.include?(log_level) }
          .flat_map { |_level, message| message }
      end
    end
  end
end
