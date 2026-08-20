# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ActiveRecord
      class SqlFormatter < Appsignal::EventFormatter
        # A query is an outgoing call to a datastore.
        def opentelemetry_kind
          :client
        end

        # The payload carries the connection the query ran on (Rails 6.0+),
        # whose `adapter_name` is each adapter's own name for itself, such as
        # `"PostgreSQL"` or `"Mysql2"`. A name the mapping does not recognise
        # is left to the SQL sentinel, same as an adapter this gem has never
        # heard of.
        def opentelemetry_attributes(payload)
          name = Appsignal::OpenTelemetry::SqlDbSystem.name_for_active_record(
            payload[:connection]&.adapter_name
          )
          return unless name

          { "db.system.name" => name }
        end

        def format(payload)
          [payload[:name], payload[:sql], SQL_BODY_FORMAT]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "sql.active_record",
  Appsignal::EventFormatter::ActiveRecord::SqlFormatter
)
