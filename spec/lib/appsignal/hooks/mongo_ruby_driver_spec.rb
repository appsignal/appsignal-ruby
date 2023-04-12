describe Appsignal::Hooks::MongoRubyDriverHook do
  require "appsignal/integrations/mongo_ruby_driver"

  context "with mongo ruby driver" do
    let(:subscriber) { Appsignal::Hooks::MongoMonitorSubscriber.new }
    before do
      allow(Appsignal::Hooks::MongoMonitorSubscriber).to receive(:new).and_return(subscriber)
    end

    before(:context) do
      module Mongo
        module Monitoring
          COMMAND = "command".freeze

          class Global
            def subscribe
            end
          end
        end
      end
    end
    after(:context) { Object.send(:remove_const, :Mongo) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "adds a subscriber to Mongo::Monitoring" do
      expect(Mongo::Monitoring::Global).to receive(:subscribe)
        .with("command", subscriber)
        .at_least(:once)

      Appsignal::Hooks::MongoRubyDriverHook.new.install
    end
  end

  context "without mongo ruby driver" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
