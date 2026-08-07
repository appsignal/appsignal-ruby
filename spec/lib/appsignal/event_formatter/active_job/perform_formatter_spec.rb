describe Appsignal::EventFormatter::ActiveJob::PerformFormatter do
  let(:klass) { described_class }
  let(:formatter) { klass.new }

  it "registers perform.active_job" do
    expect(Appsignal::EventFormatter.registered?("perform.active_job", klass)).to be_truthy
  end

  describe "#opentelemetry_attributes" do
    subject { formatter.opentelemetry_attributes(payload) }

    context "with a job that names its queue" do
      let(:job) { double(:queue_name => "default") }
      let(:payload) { { :job => job } }

      it "describes performing a job on that queue" do
        is_expected.to eq(
          "messaging.system" => "active_job",
          "messaging.operation.name" => "perform",
          "messaging.operation.type" => "process",
          "messaging.destination.name" => "default"
        )
      end
    end

    context "without a job" do
      let(:payload) { {} }

      it "describes performing a job without naming a queue" do
        is_expected.to eq(
          "messaging.system" => "active_job",
          "messaging.operation.name" => "perform",
          "messaging.operation.type" => "process"
        )
      end
    end
  end

  describe "#format" do
    subject { formatter.format(:job => double(:queue_name => "default")) }

    # The job's own transaction carries its title, so this event needs none.
    it { is_expected.to be_nil }
  end
end
