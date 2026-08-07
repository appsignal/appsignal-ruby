# frozen_string_literal: true

describe Appsignal::EventFormatter::Rom::SqlFormatter do
  let(:klass) { described_class }
  let(:formatter) { klass.new }

  it "registers the sql event formatter" do
    expect(Appsignal::EventFormatter.registered?("sql.dry", klass)).to be_truthy
  end

  describe "#opentelemetry_kind" do
    subject { formatter.opentelemetry_kind }

    it { is_expected.to eq :client }
  end

  describe "#opentelemetry_scope" do
    subject { formatter.opentelemetry_scope }

    # These events arrive over dry-monitor, but ROM is what emits them, and the
    # scope names the library the instrumentation is for.
    it { is_expected.to eq ["appsignal-ruby/rom", Appsignal::VERSION] }
  end

  describe "#format" do
    subject { formatter.format(payload) }

    # ROM reports the database it is talking to as the event's `name`, as
    # Sequel's database type. Every ROM query is named after ROM whichever
    # database that is, so that they are all in one group.
    context "with a PostgreSQL database" do
      let(:payload) { { :name => :postgres, :query => "SELECT * FROM users" } }

      it { is_expected.to eq ["query.rom", "SELECT * FROM users", 1] }
    end

    context "with a SQLite database" do
      let(:payload) { { :name => :sqlite, :query => "SELECT * FROM users" } }

      it { is_expected.to eq ["query.rom", "SELECT * FROM users", 1] }
    end
  end
end
