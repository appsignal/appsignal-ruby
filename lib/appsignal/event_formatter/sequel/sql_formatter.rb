module Appsignal
  class EventFormatter
    module Sequel
      class SqlFormatter < Appsignal::EventFormatter
        register 'sql.sequel'

        def format(payload)
          [nil, payload[:sql], SQL_BODY_FORMAT]
        end
      end
    end
  end
end
