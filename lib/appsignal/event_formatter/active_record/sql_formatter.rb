module Appsignal
  class EventFormatter
    module ActiveRecord
      class SqlFormatter < Appsignal::EventFormatter
        register 'sql.active_record'

        def format(payload)
          [
            payload[:name],
            Appsignal::Utils.encode_utf8(payload[:sql]),
            SQL_BODY_FORMAT
          ]
        end
      end
    end
  end
end
