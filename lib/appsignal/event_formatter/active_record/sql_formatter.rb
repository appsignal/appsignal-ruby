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
