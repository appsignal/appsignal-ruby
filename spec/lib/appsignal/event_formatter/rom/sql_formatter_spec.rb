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

  describe "#format" do
    let(:payload) do
      {
        :name => "postgres",
        :query => "SELECT * FROM users"
      }
    end
    subject { formatter.format(payload) }

    it { is_expected.to eq ["query.postgres", "SELECT * FROM users", 1] }
  end
end
