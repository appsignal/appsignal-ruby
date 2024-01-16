describe Appsignal::Hooks::RedisHook do
  before do
    Appsignal.config = project_fixture_config
  end

  if DependencyHelper.redis_present?
    context "with redis" do
      if DependencyHelper.redis_client_present?
        context "with redis-client" do
          context "with instrumentation enabled" do
            describe "#dependencies_present?" do
              subject { described_class.new.dependencies_present? }

              it { is_expected.to be_falsey }
            end
          end
        end
      else
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

              it "prepends instrumentation module" do
                # Test if the last included module (prepended module) was our
                # integration. That's not certain with the assertions below
                # because we have to overwrite the `process` method for the test.
                expect(Redis::Client.included_modules.first)
                  .to eql(Appsignal::Integrations::RedisIntegration)
              end
            end

            context "requirements" do
              it "driver should have the write method" do
                # Since we stub the client class below, to make sure that we don't
                # create a real connection, the test won't fail if the method definition
                # is changed.
                method = Redis::Client.instance_method(:call)
                expect(method.arity).to eql(1)
              end
            end

            context "instrumentation" do
              before do
                start_agent
                # Stub Redis::Client class so that it doesn't perform an actual
                # Redis query. This class will be included (prepended) with the
                # AppSignal Redis integration.
                stub_const("Redis::Client", Class.new do
                  def id
                    "stub_id"
                  end

                  def write(_commands)
                    "stub_write"
                  end
                end)
                # Load the integration again for the stubbed Redis::Client class.
                # Call it directly because {Appsignal::Hooks.load_hooks} keeps
                # track if it was installed already or not.
                Appsignal::Hooks::RedisHook.new.install
              end
              let!(:transaction) do
                Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
              end
              around { |example| keep_transactions { example.run } }

              it "instrument a redis call" do
                client = Redis::Client.new
                expect(client.write([:get, "key"])).to eql("stub_write")

                transaction_hash = transaction.to_h
                expect(transaction_hash["events"]).to include(
                                                        hash_including(
                                                          "name" => "query.redis",
                                                          "body" => "get ?",
                                                          "title" => "stub_id"
                                                        )
                                                      )
              end

              it "instrument a redis script call" do
                client = Redis::Client.new
                script = "return redis.call('set',KEYS[1],ARGV[1])"
                keys = ["foo"]
                argv = ["bar"]
                expect(client.write([:eval, script, keys.size, keys, argv])).to eql("stub_write")

                transaction_hash = transaction.to_h
                expect(transaction_hash["events"]).to include(
                                                        hash_including(
                                                          "name" => "query.redis",
                                                          "body" => "#{script} ? ?",
                                                          "title" => "stub_id"
                                                        )
                                                      )
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
