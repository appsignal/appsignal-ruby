describe Appsignal::Hooks::RedisHook do
  before :all do
    start_agent
  end

  context "with redis" do
    context "with redis" do
      before :all do
        class Redis
          class Client
            def process(_commands)
              1
            end
          end
          VERSION = "1.0"
        end
      end

      context "and redis instrumentation enabled" do
        before :all do
          Appsignal.config.config_hash[:instrument_redis] = true
          Appsignal::Hooks::RedisHook.new.install
        end
        after(:all) { Object.send(:remove_const, :Redis) }

        its(:dependencies_present?) { should be_true }

        it "should instrument a redis call" do
          Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
          expect(Appsignal::Transaction.current).to receive(:start_event)
            .at_least(:once)
          expect(Appsignal::Transaction.current).to receive(:finish_event)
            .at_least(:once)
            .with("query.redis", nil, nil, 0)

          client = Redis::Client.new

          client.process([]).should eq 1
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
