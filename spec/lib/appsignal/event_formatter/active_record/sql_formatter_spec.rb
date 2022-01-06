describe Appsignal::EventFormatter::ActiveRecord::SqlFormatter do
  let(:klass)     { described_class }
  let(:formatter) { klass.new }

  it "should register sql.active_record" do
    expect(Appsignal::EventFormatter.registered?("sql.active_record", klass)).to be_truthy
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
end
