require 'spec_helper'

describe Appsignal::Hooks::RedisHook do
  before :all do
    Appsignal.config = project_fixture_config
  end

  context "with redis" do
    context "with redis" do
      before :all do
        module Redis
          class Client
            def process(commands, &block)
              1
            end
          end
          VERSION = '1.0'
        end
      end

      context "and redis instrumentation enabled" do
        let(:events) { [] }
        before :all do
          Appsignal.config.config_hash[:instrument_redis] = true
          Appsignal::Hooks::RedisHook.new.install
        end
        before do
          ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
            events << ActiveSupport::Notifications::Event.new(*args)
          end
        end
        after(:all) { Object.send(:remove_const, :Redis) }

        its(:dependencies_present?) { should be_true }

        it "should generate an event for a redis call" do
          client = Redis::Client.new

          client.process([]).should == 1

          event = events.last
          event.name.should == 'query.redis'
        end
      end
    end

    context "and redis instrumentation disabled" do
      before :all do
        Appsignal.config.config_hash[:instrument_net_http] = false
      end

      its(:dependencies_present?) { should be_false }
    end
  end

  context "without redis" do
    its(:dependencies_present?) { should be_false }
  end
end
