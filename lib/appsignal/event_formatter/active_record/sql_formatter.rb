module Appsignal
  class EventFormatter
    module ActiveRecord
      class SqlFormatter < Appsignal::EventFormatter
        register 'sql.active_record'

        SINGLE_QUOTED_STRING = /'(.?|[^']).*'/.freeze
        DOUBLE_QUOTED_STRING = /"(.?|[^"]).*"/.freeze
        IN_OPERATOR_CONTENT  = /(IN \()[^\)]+(\))/.freeze
        NUMERIC              = /\d*\.?\d+/.freeze
        REPLACEMENT          = '?'.freeze
        IN_REPLACEMENT       = '\1?\2'.freeze
        SCHEMA               = 'SCHEMA'.freeze

        attr_reader :adapter_uses_double_quoted_table_names

        def initialize
          @connection_config = connection_config
          @adapter_uses_double_quoted_table_names = adapter_uses_double_quoted_table_names?
        rescue ::ActiveRecord::ConnectionNotEstablished
          Appsignal::EventFormatter.unregister('sql.active_record', self.class)
          Appsignal.logger.error('Error while getting ActiveRecord connection info, unregistering sql.active_record event formatter')
        end

        def format(payload)
          return nil if schema_query?(payload) || !payload[:sql]
          sql_string = payload[:sql].dup
          unless adapter_uses_double_quoted_table_names
            sql_string.gsub!(DOUBLE_QUOTED_STRING, REPLACEMENT)
          end
          sql_string.gsub!(SINGLE_QUOTED_STRING, REPLACEMENT)
          sql_string.gsub!(IN_OPERATOR_CONTENT, IN_REPLACEMENT)
          sql_string.gsub!(NUMERIC, REPLACEMENT)
          [payload[:name], sql_string]
        end

        protected

          def schema_query?(payload)
            payload[:name] == SCHEMA
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
      end
    end
  end
end
