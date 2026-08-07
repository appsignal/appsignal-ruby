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

        # dry-monitor reports an event under an id rather than a name, so the
        # first value here names the event. Naming it after ROM keeps every ROM
        # query in one group.
        #
        # The payload also says which database ROM is talking to, as Sequel's
        # database type. That is deliberately not part of the name. It would
        # put an application's queries in a group per database engine, so the
        # same application would report one group in production and another in
        # its tests.
        def format(payload)
          ["query.rom", payload[:query], SQL_BODY_FORMAT]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "sql.dry",
  Appsignal::EventFormatter::Rom::SqlFormatter
)
