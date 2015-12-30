require 'spec_helper'

describe Appsignal::Hooks::MongoRubyDriverHook do
  require 'appsignal/integrations/mongo_ruby_driver'

  context "with mongo ruby driver" do
    let(:subscriber) { Appsignal::Hooks::MongoMonitorSubscriber.new }
    before { Appsignal::Hooks::MongoMonitorSubscriber.stub(:new => subscriber) }

    before(:all) do
      module Mongo
        module Monitoring
          COMMAND = 'command'

          class Global
            def subscribe
            end
          end
        end
      end
    end
    after(:all) { Object.send(:remove_const, :Mongo) }

    its(:dependencies_present?) { should be_true }

    it "adds a subscriber to Mongo::Monitoring" do
      Mongo::Monitoring::Global.should receive(:subscribe)
        .with('command', subscriber)
        .at_least(:once)

      Appsignal::Hooks::MongoRubyDriverHook.new.install
    end
  end

  context "without mongo ruby driver" do
    its(:dependencies_present?) { should be_false }
  end
end
