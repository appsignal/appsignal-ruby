describe Appsignal::EventFormatter::ActiveRecord::SqlFormatter do
  let(:klass)     { described_class }
  let(:formatter) { klass.new }

  it "should register sql.active_record" do
    expect(Appsignal::EventFormatter.registered?("sql.active_record", klass)).to be_truthy
  end

  describe "#opentelemetry_kind" do
    subject { formatter.opentelemetry_kind }

    it { is_expected.to eq :client }
  end

  describe "#format" do
    let(:payload) do
      {
        :name => "User load",
        :sql => "SELECT * FROM users"
      }
    end

    subject { formatter.format(payload) }

    it { is_expected.to eq ["User load", "SELECT * FROM users", 1] }
  end

  describe "#opentelemetry_attributes" do
    subject { formatter.opentelemetry_attributes(payload) }

    context "with a connection whose adapter the mapping recognises" do
      let(:payload) { { :connection => double(:adapter_name => "PostgreSQL") } }

      it "names the engine" do
        is_expected.to eq("db.system.name" => "postgresql")
      end
    end

    context "with a connection whose adapter is activerecord-sqlserver-adapter's" do
      let(:payload) { { :connection => double(:adapter_name => "SQLServer") } }

      it "names the engine with the older semantic conventions value" do
        is_expected.to eq("db.system.name" => "mssql")
      end
    end

    context "with a connection whose adapter is activerecord-oracle_enhanced-adapter's" do
      let(:payload) { { :connection => double(:adapter_name => "OracleEnhanced") } }

      it "names the engine" do
        is_expected.to eq("db.system.name" => "oracle")
      end
    end

    context "with a connection whose adapter the mapping does not recognise" do
      let(:payload) { { :connection => double(:adapter_name => "DB2") } }

      it "names nothing, leaving the SQL sentinel to apply" do
        is_expected.to be_nil
      end
    end

    context "without a connection (Rails versions that do not report one)" do
      let(:payload) { {} }

      it "names nothing, leaving the SQL sentinel to apply" do
        is_expected.to be_nil
      end
    end
  end
end
