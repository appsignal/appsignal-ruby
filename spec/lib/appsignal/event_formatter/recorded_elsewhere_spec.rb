describe Appsignal::EventFormatter::RecordedElsewhere do
  let(:klass) { described_class }
  let(:formatter) { klass.new }

  # Which events are claimed with this, and when, is up to the integration that
  # records each of them. Those are covered by that integration's own specs.
  describe "#record?" do
    subject { formatter.record? }

    it { is_expected.to be(false) }
  end

  it "keeps the generic paths from recording the event it is registered for" do
    Appsignal::EventFormatter.register("mock.claimed", klass)

    expect(Appsignal::EventFormatter.record?("mock.claimed")).to be(false)
  ensure
    Appsignal::EventFormatter.unregister("mock.claimed", klass)
  end

  describe "#format" do
    subject { formatter.format(:name => "claimed") }

    it { is_expected.to be_nil }
  end
end
