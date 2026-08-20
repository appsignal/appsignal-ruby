# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module Rom
      class SqlFormatter < Appsignal::EventFormatter
        # These events arrive over dry-monitor, which is a notification bus
        # rather than a library that queries a database. ROM is what emits
        # them, so that is what the scope names.
        def opentelemetry_scope
          ["appsignal-ruby/rom", Appsignal::VERSION]
        end

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

        # The payload's `name` is Sequel's `database_type` symbol for the
        # database ROM is talking to, so this uses Sequel's own lookup
        # rather than a coincidentally similar one. A symbol the mapping does
        # not recognise is left to the SQL sentinel, same as an engine this
        # gem has never heard of.
        def opentelemetry_attributes(payload)
          name = Appsignal::OpenTelemetry::SqlDbSystem.name_for_sequel(payload[:name])
          return unless name

          { "db.system.name" => name }
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "sql.dry",
  Appsignal::EventFormatter::Rom::SqlFormatter
)
