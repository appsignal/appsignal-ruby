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
        # If scheme is SQL-like, try to sanitize it, otherwise clear the body
        if SQL_CLASSES.include?(self.class.to_s)
          body_content = message.query
          body_format = Appsignal::EventFormatter::SQL_BODY_FORMAT
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
          :opentelemetry_scope => ["appsignal-ruby-data_mapper", Appsignal::VERSION]
        )
        super
      end
    end
  end
end
