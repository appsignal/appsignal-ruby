describe Appsignal::Hooks::RedisClientHook do
  before do
    Appsignal.config = project_fixture_config
  end

  if DependencyHelper.redis_client_present?
    context "with redis_client" do
      context "with instrumentation enabled" do
        describe "#dependencies_present?" do
          subject { described_class.new.dependencies_present? }

          it { is_expected.to be_truthy }
        end

        context "with rest-client gem" do
          describe "integration" do
            before do
              Appsignal.config.config_hash[:instrument_redis] = true
            end

            context "install" do
              before do
                Appsignal::Hooks.load_hooks
              end

              it "includes the integration for the ruby connection" do
                # Test if the last included module (prepended module) was our
                # integration. That's not certain with the assertions below
                # because we have to overwrite the `process` method for the test.
                expect(RedisClient::RubyConnection.included_modules.first)
                  .to eql(Appsignal::Integrations::RedisClientIntegration)
              end
            end

            context "requirements" do
              it "driver should have the write method" do
                # Since we stub the driver class below, to make sure that we don't
                # create a real connection, the test won't fail if the method definition
                # is changed.
                method = RedisClient::RubyConnection.instance_method(:write)
                expect(method.arity).to eql(1)
              end
            end

            context "instrumentation" do
              before do
                start_agent
                # Stub RedisClient::RubyConnection class so that it doesn't perform an actual
                # Redis query. This class will be included (prepended) with the
                # AppSignal Redis integration.
                stub_const("RedisClient::RubyConnection", Class.new do
                  def initialize(config)
                    @config = config
                  end

                  def write(_commands)
                    "stub_write"
                  end
                end)
                # Load the integration again for the stubbed RedisClient::RubyConnection class.
                # Call it directly because {Appsignal::Hooks.load_hooks} keeps
                # track if it was installed already or not.
                Appsignal::Hooks::RedisClientHook.new.install
              end
              let!(:transaction) do
                Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
              end
              let!(:client_config) { RedisClient::Config.new(:id => "stub_id") }
              around { |example| keep_transactions { example.run } }

              it "instrument a redis call" do
                connection = RedisClient::RubyConnection.new client_config
                expect(connection.write([:get, "key"])).to eql("stub_write")

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
                connection = ::RedisClient::RubyConnection.new client_config
                script = "return redis.call('set',KEYS[1],ARGV[1])"
                keys = ["foo"]
                argv = ["bar"]
                expect(connection.write([:eval, script, keys.size, keys,
                                         argv])).to eql("stub_write")

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

        if DependencyHelper.hiredis_client_present?
          context "with hiredis driver" do
            describe "integration" do
              before do
                Appsignal.config.config_hash[:instrument_redis] = true
              end

              context "install" do
                before do
                  Appsignal::Hooks.load_hooks
                end

                it "includes the integration in the HiredisConnection class" do
                  # Test if the last included module (prepended module) was our
                  # integration. That's not certain with the assertions below
                  # because we have to overwrite the `process` method for the test.
                  expect(RedisClient::HiredisConnection.included_modules.first)
                    .to eql(Appsignal::Integrations::RedisClientIntegration)
                end
              end

              context "requirements" do
                it "driver should have the write method" do
                  # Since we stub the driver class below, to make sure that we don't
                  # create a real connection, the test won't fail if the method definition
                  # is changed.
                  method = RedisClient::HiredisConnection.instance_method(:write)
                  expect(method.arity).to eql(1)
                end
              end

              context "instrumentation" do
                before do
                  start_agent
                  # Stub RedisClient::HiredisConnection class so that it doesn't perform an actual
                  # Redis query. This class will be included (prepended) with the
                  # AppSignal Redis integration.
                  stub_const("RedisClient::HiredisConnection", Class.new do
                    def initialize(config)
                      @config = config
                    end

                    def write(_commands)
                      "stub_write"
                    end
                  end)
                  # Load the integration again for the stubbed RedisClient::HiredisConnection class.
                  # Call it directly because {Appsignal::Hooks.load_hooks} keeps
                  # track if it was installed already or not.
                  Appsignal::Hooks::RedisClientHook.new.install
                end
                let!(:transaction) do
                  Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST,
                    "test")
                end
                let!(:client_config) { RedisClient::Config.new(:id => "stub_id") }
                around { |example| keep_transactions { example.run } }

                it "instrument a redis call" do
                  connection = RedisClient::HiredisConnection.new client_config
                  expect(connection.write([:get, "key"])).to eql("stub_write")

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
                  connection = ::RedisClient::HiredisConnection.new client_config
                  script = "return redis.call('set',KEYS[1],ARGV[1])"
                  keys = ["foo"]
                  argv = ["bar"]
                  expect(connection.write([:eval, script, keys.size, keys,
                                           argv])).to eql("stub_write")

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
