module Appsignal
  class EventFormatter
    module ActiveRecord
      class SqlFormatter < Appsignal::EventFormatter
        register 'sql.active_record'

        SINGLE_QUOTE       = /\\'/.freeze
        DOUBLE_QUOTE       = /\\"/.freeze
        QUOTED_DATA        = /(?:"[^"]+"|'[^']+')/.freeze
        SINGLE_QUOTED_DATA = /(?:'[^']+')/.freeze
        IN_ARRAY           = /(IN \()[^\)]+(\))/.freeze
        NUMERIC_DATA       = /\b\d+\b/.freeze
        SANITIZED_VALUE    = '\1?\2'.freeze

        attr_reader :adapter_uses_double_quoted_table_names, :adapter_uses_prepared_statements

        def initialize
          @connection_config = connection_config
          @adapter_uses_prepared_statements = adapter_uses_prepared_statements?
          @adapter_uses_double_quoted_table_names = adapter_uses_double_quoted_table_names?
        rescue ::ActiveRecord::ConnectionNotEstablished
          Appsignal::EventFormatter.unregister('sql.active_record', self.class)
          Appsignal.logger.error('Error while getting ActiveRecord connection info, unregistering sql.active_record event formatter')
        end

        def format(payload)
          return nil if schema_query?(payload) || !payload[:sql]
          if adapter_uses_prepared_statements
            [payload[:name], payload[:sql]]
          else
            sql_string = payload[:sql].dup
            if adapter_uses_double_quoted_table_names
              sql_string.gsub!(SINGLE_QUOTE, SANITIZED_VALUE)
              sql_string.gsub!(SINGLE_QUOTED_DATA, SANITIZED_VALUE)
            else
              sql_string.gsub!(SINGLE_QUOTE, SANITIZED_VALUE)
              sql_string.gsub!(DOUBLE_QUOTE, SANITIZED_VALUE)
              sql_string.gsub!(QUOTED_DATA, SANITIZED_VALUE)
            end
            sql_string.gsub!(IN_ARRAY, SANITIZED_VALUE)
            sql_string.gsub!(NUMERIC_DATA, SANITIZED_VALUE)
            [payload[:name], sql_string]
          end
        end

        protected

          def schema_query?(payload)
            payload[:name] == 'SCHEMA'
          end

          def connection_config
            # TODO handle ActiveRecord::ConnectionNotEstablished
            if ::ActiveRecord::Base.respond_to?(:connection_config)
              ::ActiveRecord::Base.connection_config
            else
              ::ActiveRecord::Base.connection_pool.spec.config
            end
          end

          def adapter_uses_double_quoted_table_names?
            adapter = @connection_config[:adapter]
            adapter =~ /postgres/ || adapter =~ /sqlite/
          end

          def adapter_uses_prepared_statements?
            return false unless adapter_uses_double_quoted_table_names?
            return true if @connection_config[:prepared_statements].nil?
            @connection_config[:prepared_statements]
          end
      end
    end
  end
end
