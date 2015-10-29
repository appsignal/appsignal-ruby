require 'spec_helper'

describe "Net::HTTP instrumentation" do
  let(:file) { File.expand_path('lib/appsignal/instrumentations/redis.rb') }

  let(:events) { [] }
  before do
    ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

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

    before do
      load file
    end

    it "should generate an event for a redis call" do
      client = Redis::Client.new

      client.process([]).should == 1

      event = events.last
      event.name.should == 'query.redis'
    end
  end

  context "without redis" do
    before(:all) { Object.send(:remove_const, :Redis) }

    specify { expect { ::Redis }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
