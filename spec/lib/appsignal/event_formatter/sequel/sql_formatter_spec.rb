describe Appsignal::EventFormatter::Sequel::SqlFormatter do
  let(:klass)     { described_class }
  let(:formatter) { klass.new }

  it "registers the sql.sequel event formatter" do
    expect(Appsignal::EventFormatter.registered?("sql.sequel", klass)).to be_truthy
  end

  describe "#format" do
    before do
      stub_const(
        "SequelDatabaseTypeClass",
        Class.new do
          def self.to_s
            "SequelDatabaseTypeClassToString"
          end
        end
      )
    end
    let(:payload) do
      {
        :name => SequelDatabaseTypeClass,
        :sql => "SELECT * FROM users"
      }
    end
    subject { formatter.format(payload) }

    it { is_expected.to eq ["SequelDatabaseTypeClassToString", "SELECT * FROM users", 1] }
  end
end
