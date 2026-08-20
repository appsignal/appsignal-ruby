# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    module DataMapperLogListener
      SQL_CLASSES = [
        "DataObjects::SqlServer::Connection",
        "DataObjects::Sqlite3::Connection",
        "DataObjects::Mysql::Connection",
        "DataObjects::Postgres::Connection"
      ].freeze

      def log(message)
        attributes = {}

        # If scheme is SQL-like, try to sanitize it, otherwise clear the body
        if SQL_CLASSES.include?(self.class.to_s)
          body_content = message.query
          body_format = Appsignal::EventFormatter::SQL_BODY_FORMAT
          # The connection class names the engine it talks to, one of the four
          # SQL_CLASSES above; a class this map does not recognise leaves the
          # SQL sentinel to apply, same as it would for a fifth SQL_CLASSES
          # entry this map has not been taught about.
          db_system = Appsignal::OpenTelemetry::SqlDbSystem.name_for_data_mapper(self.class.to_s)
          attributes["db.system.name"] = db_system if db_system
        else
          body_content = ""
          body_format = Appsignal::EventFormatter::DEFAULT
        end

        # Record event. The query is an outgoing call to the database, so tag it
        # as a client span (collector mode); no-op in agent mode.
        Appsignal::Transaction.current.record_event(
          "query.data_mapper",
          "DataMapper Query",
          body_content,
          message.duration,
          body_format,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/data_mapper", Appsignal::VERSION],
          :opentelemetry_attributes => attributes
        )
        super
      end
    end
  end
end
