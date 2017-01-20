describe Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter do
  let(:klass)     { Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter }
  let(:formatter) { klass.new }

  it "should register instantiation.active_record" do
    expect(Appsignal::EventFormatter.registered?("instantiation.active_record", klass)).to be_truthy
  end

  describe "#format" do
    let(:payload) do
      {
        :record_count => 1,
        :class_name => "User"
      }
    end

    subject { formatter.format(payload) }

    it { is_expected.to eq ["User", nil] }
  end
end
