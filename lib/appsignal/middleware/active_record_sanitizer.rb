module Appsignal
  module Middleware
    class ActiveRecordSanitizer
      TARGET_EVENT_NAME = 'sql.active_record'.freeze

      SINGLE_QUOTE       = /\\'/.freeze
      DOUBLE_QUOTE       = /\\"/.freeze
      QUOTED_DATA        = /(?:"[^"]+"|'[^']+')/.freeze
      SINGLE_QUOTED_DATA = /(?:'[^']+')/.freeze
      IN_ARRAY           = /(IN \()[^\)]+(\))/.freeze
      NUMERIC_DATA       = /\b\d+\b/.freeze

      SANITIZED_VALUE = '\1?\2'.freeze

      def call(event)
        if event.name == TARGET_EVENT_NAME
          unless schema_query?(event) || adapter_uses_prepared_statements?
            query_string = event.payload[:sql]
            if query_string
              if adapter_uses_double_quoted_table_names?
                query_string.gsub!(SINGLE_QUOTE, SANITIZED_VALUE)
                query_string.gsub!(SINGLE_QUOTED_DATA, SANITIZED_VALUE)
              else
                query_string.gsub!(SINGLE_QUOTE, SANITIZED_VALUE)
                query_string.gsub!(DOUBLE_QUOTE, SANITIZED_VALUE)
                query_string.gsub!(QUOTED_DATA, SANITIZED_VALUE)
              end
              query_string.gsub!(IN_ARRAY, SANITIZED_VALUE)
              query_string.gsub!(NUMERIC_DATA, SANITIZED_VALUE)
            end
          end
          event.payload.delete(:connection_id)
          event.payload.delete(:binds)
        end
        yield
      end

      def schema_query?(event)
        event.payload[:name] == 'SCHEMA'
      end

      def connection_config
        @connection_config ||= if ActiveRecord::Base.respond_to?(:connection_config)
          ActiveRecord::Base.connection_config
        else
          ActiveRecord::Base.connection_pool.spec.config
        end
      end

      def adapter_uses_double_quoted_table_names?
        adapter = connection_config[:adapter]
        adapter =~ /postgres/ || adapter =~ /sqlite/
      end

      def adapter_uses_prepared_statements?
        return false unless adapter_uses_double_quoted_table_names?
        return true if connection_config[:prepared_statements].nil?
        connection_config[:prepared_statements]
      end
    end
  end
end
