# frozen_string_literal: true

describe Appsignal::OpenTelemetry::SqlDbSystem do
  describe ".name_for_active_record" do
    it "maps ActiveRecord's ADAPTER_NAME to the semantic conventions value" do
      expect(described_class.name_for_active_record("PostgreSQL")).to eq("postgresql")
      expect(described_class.name_for_active_record("Mysql2")).to eq("mysql")
      expect(described_class.name_for_active_record("Trilogy")).to eq("mysql")
      expect(described_class.name_for_active_record("SQLite")).to eq("sqlite")
    end

    # activerecord-sqlserver-adapter and activerecord-oracle_enhanced-adapter
    # are separate gems, but declare ADAPTER_NAME the same way the adapters
    # Rails bundles do.
    it "maps activerecord-sqlserver-adapter's ADAPTER_NAME to the older semconv value" do
      expect(described_class.name_for_active_record("SQLServer")).to eq("mssql")
    end

    it "maps activerecord-oracle_enhanced-adapter's ADAPTER_NAME to the older semconv value" do
      expect(described_class.name_for_active_record("OracleEnhanced")).to eq("oracle")
    end

    it "returns nil for an adapter it does not recognise" do
      expect(described_class.name_for_active_record("DB2")).to be_nil
      expect(described_class.name_for_active_record(nil)).to be_nil
    end

    it "does not recognise Sequel's or DataMapper's vocabulary" do
      expect(described_class.name_for_active_record(:postgres)).to be_nil
      expect(described_class.name_for_active_record("DataObjects::Postgres::Connection")).to be_nil
    end
  end

  describe ".name_for_sequel" do
    it "maps Sequel's database_type to the semantic conventions value" do
      expect(described_class.name_for_sequel(:postgres)).to eq("postgresql")
      expect(described_class.name_for_sequel(:mysql)).to eq("mysql")
      expect(described_class.name_for_sequel(:sqlite)).to eq("sqlite")
    end

    # SQL Server and Oracle map to the older semantic conventions values,
    # `mssql` and `oracle`, rather than the current registry's
    # `microsoft.sql_server` and `oracle.db`, because those are what the
    # AppSignal collector's sanitizer recognizes today.
    it "maps SQL Server and Oracle to the older semantic conventions values" do
      expect(described_class.name_for_sequel(:mssql)).to eq("mssql")
      expect(described_class.name_for_sequel(:oracle)).to eq("oracle")
    end

    it "returns nil for a database_type it does not recognise" do
      expect(described_class.name_for_sequel(:db2)).to be_nil
      expect(described_class.name_for_sequel(nil)).to be_nil
    end

    it "does not recognise ActiveRecord's or DataMapper's vocabulary" do
      expect(described_class.name_for_sequel("PostgreSQL")).to be_nil
      expect(described_class.name_for_sequel("DataObjects::Postgres::Connection")).to be_nil
    end
  end

  describe ".name_for_data_mapper" do
    it "maps DataMapper's DataObjects connection classes to the semantic conventions value" do
      expect(described_class.name_for_data_mapper("DataObjects::Postgres::Connection"))
        .to eq("postgresql")
      expect(described_class.name_for_data_mapper("DataObjects::Mysql::Connection"))
        .to eq("mysql")
      expect(described_class.name_for_data_mapper("DataObjects::Sqlite3::Connection"))
        .to eq("sqlite")
    end

    # SQL Server maps to the older semantic conventions value, `mssql`,
    # rather than the current registry's `microsoft.sql_server`, because
    # that is what the AppSignal collector's sanitizer recognizes today.
    it "maps SQL Server to the older semantic conventions value" do
      expect(described_class.name_for_data_mapper("DataObjects::SqlServer::Connection"))
        .to eq("mssql")
    end

    it "returns nil for a connection class it does not recognise" do
      expect(described_class.name_for_data_mapper("DataObjects::Oracle::Connection")).to be_nil
      expect(described_class.name_for_data_mapper(nil)).to be_nil
    end

    it "does not recognise ActiveRecord's or Sequel's vocabulary" do
      expect(described_class.name_for_data_mapper("PostgreSQL")).to be_nil
      expect(described_class.name_for_data_mapper(:postgres)).to be_nil
    end
  end
end
