# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module Rom
      class SqlFormatter < Appsignal::EventFormatter
        # A query is an outgoing call to a datastore.
        def opentelemetry_kind
          :client
        end

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
