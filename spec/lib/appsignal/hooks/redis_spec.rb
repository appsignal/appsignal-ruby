describe Appsignal::Hooks::RedisHook do
  before do
    Appsignal.config = project_fixture_config
    Appsignal::Hooks.load_hooks
  end

  if DependencyHelper.redis_present?
    context "with redis" do
      context "with instrumentation enabled" do
        before do
          Appsignal.config.config_hash[:instrument_redis] = true
          allow_any_instance_of(Redis::Client).to receive(:process_without_appsignal).and_return(1)
        end

        describe "#dependencies_present?" do
          subject { described_class.new.dependencies_present? }

          it { is_expected.to be_truthy }
        end

        it "should instrument a redis call" do
          Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
          expect(Appsignal::Transaction.current).to receive(:start_event)
            .at_least(:once)
          expect(Appsignal::Transaction.current).to receive(:finish_event)
            .at_least(:once)
            .with("query.redis", "redis://127.0.0.1:6379/0", "get ?", 0)

          client = Redis::Client.new
          expect(client.process([[:get, 'key']])).to eq 1
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
