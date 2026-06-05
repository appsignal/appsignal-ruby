describe Appsignal::Hooks::RedisClientHook do
  let(:options) { {} }

  if DependencyHelper.redis_client_present?
    context "with redis-client" do
      context "with instrumentation enabled" do
        describe "#dependencies_present?" do
          before { start_agent(:options => options) }
          subject { described_class.new.dependencies_present? }

          context "with gem version new than 0.14.0" do
            before { stub_const("RedisClient::VERSION", "1.2.3") }

            it { is_expected.to be_truthy }
          end

          context "with gem version 0.14.0" do
            before { stub_const("RedisClient::VERSION", "0.14.0") }

            it { is_expected.to be_truthy }
          end

          context "with gem version older than 0.14.0" do
            before { stub_const("RedisClient::VERSION", "0.13.9") }

            it { is_expected.to be_falsy }
          end
        end

        context "with rest-client gem" do
          describe "integration" do
            let(:options) { { :instrument_redis => true } }

            context "install" do
              before do
                start_agent(:options => options)
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
              before { start_agent(:options => options) }

              it "driver should have the write method" do
                # Since we stub the driver class below, to make sure that we don't
                # create a real connection, the test won't fail if the method definition
                # is changed.
                method = RedisClient::RubyConnection.instance_method(:write)
                expect(method.arity).to eql(1)
              end
            end

            context "instrumentation" do
              let(:client_config) { RedisClient::Config.new(:id => "stub_id") }
              before do
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

              describe "a redis call", :manual_start do
                def perform
                  RedisClient::RubyConnection.new(client_config).write([:get, "key"])
                end

                it "in agent mode", :agent_mode do
                  start_agent
                  transaction = http_request_transaction
                  set_current_transaction(transaction)
                  expect(perform).to eql("stub_write")

                  expect(transaction).to include_event(
                    "name" => "query.redis",
                    "body" => "get ?",
                    "title" => "stub_id"
                  )
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  transaction = http_request_transaction
                  set_current_transaction(transaction)
                  expect(perform).to eql("stub_write")
                  Appsignal::Transaction.complete_current!

                  expect(event_spans.size).to eq(1)
                  span = event_spans.first
                  expect(span.name).to eq("query.redis")
                  expect(span.parent_span_id).to eq(root_span.span_id)
                  expect(span.attributes["appsignal.body"]).to eq("get ?")
                  expect(span.attributes["appsignal.title"]).to eq("stub_id")
                  expect(span.attributes).not_to have_key("db.query.text")
                end
              end

              describe "a redis script call", :manual_start do
                let(:script) { "return redis.call('set',KEYS[1],ARGV[1])" }

                def perform
                  keys = ["foo"]
                  argv = ["bar"]
                  RedisClient::RubyConnection.new(client_config)
                    .write([:eval, script, keys.size, keys, argv])
                end

                it "in agent mode", :agent_mode do
                  start_agent
                  transaction = http_request_transaction
                  set_current_transaction(transaction)
                  expect(perform).to eql("stub_write")

                  expect(transaction).to include_event(
                    "name" => "query.redis",
                    "body" => "#{script} ? ?",
                    "title" => "stub_id"
                  )
                end

                it "in collector mode", :collector_mode do
                  start_collector_agent
                  transaction = http_request_transaction
                  set_current_transaction(transaction)
                  expect(perform).to eql("stub_write")
                  Appsignal::Transaction.complete_current!

                  expect(event_spans.size).to eq(1)
                  span = event_spans.first
                  expect(span.name).to eq("query.redis")
                  expect(span.parent_span_id).to eq(root_span.span_id)
                  expect(span.attributes["appsignal.body"]).to eq("#{script} ? ?")
                  expect(span.attributes["appsignal.title"]).to eq("stub_id")
                  expect(span.attributes).not_to have_key("db.query.text")
                end
              end
            end
          end
        end

        if DependencyHelper.hiredis_client_present?
          context "with hiredis driver" do
            describe "integration" do
              let(:options) { { :instrument_redis => true } }

              context "install" do
                before do
                  start_agent(:options => options)
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
                before { start_agent(:options => options) }

                it "driver should have the write method" do
                  # Since we stub the driver class below, to make sure that we don't
                  # create a real connection, the test won't fail if the method definition
                  # is changed.
                  method = RedisClient::HiredisConnection.instance_method(:write)
                  expect(method.arity).to eql(1)
                end
              end

              context "instrumentation" do
                let(:client_config) { RedisClient::Config.new(:id => "stub_id") }
                before do
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

                describe "a redis call", :manual_start do
                  def perform
                    RedisClient::HiredisConnection.new(client_config).write([:get, "key"])
                  end

                  it "in agent mode", :agent_mode do
                    start_agent
                    transaction = http_request_transaction
                    set_current_transaction(transaction)
                    expect(perform).to eql("stub_write")

                    expect(transaction).to include_event(
                      "name" => "query.redis",
                      "body" => "get ?",
                      "title" => "stub_id"
                    )
                  end

                  it "in collector mode", :collector_mode do
                    start_collector_agent
                    transaction = http_request_transaction
                    set_current_transaction(transaction)
                    expect(perform).to eql("stub_write")
                    Appsignal::Transaction.complete_current!

                    expect(event_spans.size).to eq(1)
                    span = event_spans.first
                    expect(span.name).to eq("query.redis")
                    expect(span.parent_span_id).to eq(root_span.span_id)
                    expect(span.attributes["appsignal.body"]).to eq("get ?")
                    expect(span.attributes["appsignal.title"]).to eq("stub_id")
                    expect(span.attributes).not_to have_key("db.query.text")
                  end
                end

                describe "a redis script call", :manual_start do
                  let(:script) { "return redis.call('set',KEYS[1],ARGV[1])" }

                  def perform
                    keys = ["foo"]
                    argv = ["bar"]
                    RedisClient::HiredisConnection.new(client_config)
                      .write([:eval, script, keys.size, keys, argv])
                  end

                  it "in agent mode", :agent_mode do
                    start_agent
                    transaction = http_request_transaction
                    set_current_transaction(transaction)
                    expect(perform).to eql("stub_write")

                    expect(transaction).to include_event(
                      "name" => "query.redis",
                      "body" => "#{script} ? ?",
                      "title" => "stub_id"
                    )
                  end

                  it "in collector mode", :collector_mode do
                    start_collector_agent
                    transaction = http_request_transaction
                    set_current_transaction(transaction)
                    expect(perform).to eql("stub_write")
                    Appsignal::Transaction.complete_current!

                    expect(event_spans.size).to eq(1)
                    span = event_spans.first
                    expect(span.name).to eq("query.redis")
                    expect(span.parent_span_id).to eq(root_span.span_id)
                    expect(span.attributes["appsignal.body"]).to eq("#{script} ? ?")
                    expect(span.attributes["appsignal.title"]).to eq("stub_id")
                    expect(span.attributes).not_to have_key("db.query.text")
                  end
                end
              end
            end
          end
        end
      end

      context "with instrumentation disabled" do
        let(:options) { { :instrument_redis => false } }

        describe "#dependencies_present?" do
          before { start_agent(:options => options) }
          subject { described_class.new.dependencies_present? }

          it { is_expected.to be_falsy }
        end
      end
    end
  else
    context "without redis-client" do
      describe "#dependencies_present?" do
        before { start_agent(:options => options) }
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_falsy }
      end
    end
  end
end
