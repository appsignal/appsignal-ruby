module Appsignal
  module Middleware
    class SqlEventSanitizer
      SINGLE_QUOTE_REGEXP   = /'(?:[^']|'')*'/.freeze
      DOUBLE_QUOTE_REGEXP   = /"(?:[^"]|"")*"/.freeze
      NUMERIC_VALUE_REGEXP  = /\b\d+\b/.freeze
      REPLACEMENT_STRING    = '?'.freeze
      TARGET_EVENT_NAME     = 'sql.activerecord'.freeze
      PAYLOAD_KEY           = :sql.freeze

      def call(event)
        event.payload[PAYLOAD_KEY].tap do |query_string|
          query_string.gsub!(SINGLE_QUOTE_REGEXP, REPLACEMENT_STRING)
          query_string.gsub!(DOUBLE_QUOTE_REGEXP, REPLACEMENT_STRING)
          query_string.gsub!(NUMERIC_VALUE_REGEXP, REPLACEMENT_STRING)
        end if matches?(event)
        yield
      end

      def matches?(event)
        event.name == TARGET_EVENT_NAME
      end

    end
  end
end
