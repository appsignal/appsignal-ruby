describe Appsignal::Hooks::RedisHook do
  before do
    Appsignal.config = project_fixture_config
  end

  if DependencyHelper.redis_present?
    context "with redis" do
      context "with instrumentation enabled" do
        describe "#dependencies_present?" do
          subject { described_class.new.dependencies_present? }

          it { is_expected.to be_truthy }
        end

        describe "integration" do
          before do
            Appsignal.config.config_hash[:instrument_redis] = true
          end

          context "install" do
            before do
              Appsignal::Hooks.load_hooks
            end

            it "does something" do
              # Test if the last included module (prepended module) was our
              # integration. That's not certain with the assertions below
              # because we have to overwrite the `process` method for the test.
              expect(Redis::Client.included_modules.first)
                .to eql(Appsignal::Integrations::RedisIntegration)
            end
          end

          context "instrumentation" do
            before do
              # Stub Redis::Client class so that it doesn't perform an actual
              # Redis query. This class will be included (prepended) with the
              # AppSignal Redis integration.
              stub_const("Redis::Client", Class.new(Redis::Client) do
                def id
                  :stub_id
                end

                def write(_command)
                  nil
                end

                def read
                  "value"
                end

                def call(*args)
                  super
                end
              end)
              # Load the integration again for the stubbed Redis::Client class.
              # Call it directly because {Appsignal::Hooks.load_hooks} keeps
              # track if it was installed already or not.
              Appsignal::Hooks::RedisHook.new.install
            end

            it "instrument a redis call" do
              Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
              expect(Appsignal::Transaction.current).to receive(:start_event)
                .at_least(:once)
              expect(Appsignal::Transaction.current).to receive(:finish_event)
                .at_least(:once)
                .with("query.redis", :stub_id, "get", 0)

              client = Redis::Client.new
              expect(client.call([:get, "key"])).to eql("value")
            end

            it "instrument a redis script call" do
              script = "return redis.call('set',KEYS[1],ARGV[1])"
              keys = ["foo"]
              argv = ["bar"]

              Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
              expect(Appsignal::Transaction.current).to receive(:start_event)
                .at_least(:once)
              expect(Appsignal::Transaction.current).to receive(:finish_event)
                .at_least(:once)
                .with("query.redis", :stub_id, script, 0)

              client = Redis::Client.new
              expect(client.call([:eval, script, keys.size, keys, argv])).to eql("value")
            end
          end
        end
      end

      context "with instrumentation disabled" do
        before do
          Appsignal.config.config_hash[:instrument_redis] = false
        end

        describe "#dependencies_present?" do
          subject { described_class.new.dependencies_present? }

          it { is_expected.to be_falsy }
        end
      end
    end
  else
    context "without redis" do
      describe "#dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_falsy }
      end
    end
  end
end
