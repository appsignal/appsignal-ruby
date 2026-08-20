# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    module SequelLogExtension
      # Add query instrumentation
      def log_yield(sql, args = nil)
        Appsignal.instrument(
          "sql.sequel",
          nil,
          sql,
          Appsignal::EventFormatter::SQL_BODY_FORMAT,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/sequel", Appsignal::VERSION]
        ) do
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::Hooks::SequelHook.sequel_db_attributes(self)
          )
          super
        end
      end
    end

    module SequelLogConnectionExtension
      # Add query instrumentation
      # @!visibility private
      def log_connection_yield(sql, conn, args = nil)
        Appsignal.instrument(
          "sql.sequel",
          nil,
          sql,
          Appsignal::EventFormatter::SQL_BODY_FORMAT,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/sequel", Appsignal::VERSION]
        ) do
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            Appsignal::Hooks::SequelHook.sequel_db_attributes(self)
          )
          super
        end
      end
    end

    class SequelHook < Appsignal::Hooks::Hook
      register :sequel

      # The query's `Sequel::Database` names both the engine it talks to and
      # the database it is connected to, neither of which the sql.sequel
      # formatter can see -- it only gets the query text. Shared by both
      # extensions above, whichever one a given Sequel version registers.
      #
      # @!visibility private
      def self.sequel_db_attributes(database)
        attributes = {}

        name = Appsignal::OpenTelemetry::SqlDbSystem.name_for_sequel(database.database_type)
        attributes["db.system.name"] = name if name

        # `opts[:database]` is Sequel's own option key for the database to
        # connect to, so it doubles as the database's name.
        namespace = database.opts[:database].to_s
        attributes["db.namespace"] = namespace unless namespace.empty?

        attributes
      end

      def dependencies_present?
        defined?(::Sequel::Database) &&
          Appsignal.config &&
          Appsignal.config[:instrument_sequel]
      end

      def install
        # Register the extension...
        if (::Sequel::MAJOR >= 4 && ::Sequel::MINOR >= 35) || ::Sequel::MAJOR >= 5
          ::Sequel::Database.register_extension(
            :appsignal_integration,
            Appsignal::Hooks::SequelLogConnectionExtension
          )
        else
          ::Sequel::Database.register_extension(
            :appsignal_integration,
            Appsignal::Hooks::SequelLogExtension
          )
        end

        # ... and automatically add it to future instances.
        ::Sequel::Database.extension(:appsignal_integration)

        Appsignal::Environment.report_enabled("sequel")
      end
    end
  end
end
