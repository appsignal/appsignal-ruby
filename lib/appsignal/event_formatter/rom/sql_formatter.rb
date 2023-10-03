# frozen_string_literal: true

module Appsignal
  class EventFormatter
    module Rom
      class SqlFormatter
        def format(payload)
          ["query.#{payload[:name]}", payload[:query], SQL_BODY_FORMAT]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "sql.dry",
  Appsignal::EventFormatter::Rom::SqlFormatter
)
