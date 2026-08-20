# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Maps a SQL library's own name for the engine it is talking to onto the
    # `db.system.name` semantic conventions value for that engine.
    #
    # Each library names engines differently, and none of them matches the
    # semantic conventions spelling, so every SQL integration needs a lookup.
    # Kept as one map per library, each keyed on that library's own
    # vocabulary, rather than one shared map: ActiveRecord's `ADAPTER_NAME`
    # strings, Sequel's `database_type` symbols, and DataMapper's
    # `DataObjects` connection class names do not collide today, but nothing
    # about that is enforced by combining them. A wrong value passed into the
    # wrong library's lookup would silently return another library's answer
    # instead of nil, and a library's own gaps would be invisible next to two
    # other libraries' complete entries. ROM is the exception: its payload
    # already carries Sequel's own `database_type` symbol, so it is
    # legitimate for it to share Sequel's map, not just convenient.
    #
    # A name none of these maps recognise returns `nil`, so the caller's own
    # `other_sql` fallback applies -- exactly what already happens for a
    # library this gem has no mapping for at all.
    #
    # This intentionally follows the older semantic conventions value set:
    # SQL Server maps to `mssql`, not the current registry's
    # `microsoft.sql_server`, and Oracle maps to `oracle`, not `oracle.db`.
    # That is what the AppSignal collector's sanitizer recognizes today;
    # emitting the newer values would silently turn sanitization off for
    # those engines' queries.
    module SqlDbSystem
      # ActiveRecord's `ADAPTER_NAME`. Rails bundles the Postgres, Mysql2,
      # SQLite and (7.1+) Trilogy adapters; SQL Server and Oracle come from
      # the separate `activerecord-sqlserver-adapter` and
      # `activerecord-oracle_enhanced-adapter` gems, which declare
      # `ADAPTER_NAME` the same way.
      ACTIVE_RECORD = {
        "PostgreSQL" => "postgresql",
        "Mysql2" => "mysql",
        "Trilogy" => "mysql",
        "SQLite" => "sqlite",
        "SQLServer" => "mssql",
        "OracleEnhanced" => "oracle"
      }.freeze

      # Sequel's `database_type`. ROM's dry-monitor payload reuses this
      # symbol directly, so `name_for_sequel` is also ROM's lookup.
      SEQUEL = {
        :postgres => "postgresql",
        :mysql => "mysql",
        :sqlite => "sqlite",
        :mssql => "mssql",
        :oracle => "oracle"
      }.freeze

      # DataMapper's `DataObjects` connection classes.
      DATA_MAPPER = {
        "DataObjects::Postgres::Connection" => "postgresql",
        "DataObjects::Mysql::Connection" => "mysql",
        "DataObjects::Sqlite3::Connection" => "sqlite",
        "DataObjects::SqlServer::Connection" => "mssql"
      }.freeze

      class << self
        # The `db.system.name` value for an ActiveRecord connection's
        # `adapter_name`, or `nil` when the adapter is not one this map
        # recognises.
        def name_for_active_record(adapter_name)
          ACTIVE_RECORD[adapter_name]
        end

        # The `db.system.name` value for Sequel's `database_type`, or `nil`
        # when it is not one this map recognises. Also the lookup ROM's
        # formatter uses, since ROM reports this same symbol.
        def name_for_sequel(database_type)
          SEQUEL[database_type]
        end

        # The `db.system.name` value for DataMapper's connection class name,
        # or `nil` when it is not one this map recognises.
        def name_for_data_mapper(connection_class_name)
          DATA_MAPPER[connection_class_name]
        end
      end
    end
  end
end
