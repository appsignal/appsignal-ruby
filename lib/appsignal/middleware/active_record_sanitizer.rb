module Appsignal
  module Middleware
    class ActiveRecordSanitizer
      TARGET_EVENT_NAME = 'sql.active_record'.freeze

      IN_ARRAY        = /(IN \()[^\)]+(\))/.freeze
      ESCAPED_QUOTES  = /\\"|\\'/.freeze
      QUOTED_DATA     = /(?:"[^"]+"|'[^']+')/.freeze
      NUMERIC_DATA    = /\b\d+\b/.freeze

      SANITIZED_VALUE = '\1?\2'.freeze

      def call(event)
        if event.name == TARGET_EVENT_NAME
          query_string = event.payload[:sql]
          if query_string
            query_string.gsub!(IN_ARRAY,        SANITIZED_VALUE)
            query_string.gsub!(ESCAPED_QUOTES,  SANITIZED_VALUE)
            query_string.gsub!(QUOTED_DATA,     SANITIZED_VALUE)
            query_string.gsub!(NUMERIC_DATA,    SANITIZED_VALUE)
          end
          event.payload.delete(:connection_id)
          yield
        end
      end
    end
  end
end
