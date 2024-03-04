describe Appsignal do
  include EnvironmentMetadataHelper

  before do
    # Make sure we have a clean state because we want to test
    # initialization here.
    Appsignal.config = nil
  end

  let(:transaction) { http_request_transaction }

  describe ".config=" do
    it "should set the config" do
      config = project_fixture_config
      expect(Appsignal.internal_logger).to_not receive(:level=)

      Appsignal.config = config
      expect(Appsignal.config).to eq config
    end
  end

  describe ".start" do
    context "with no config set beforehand" do
      it "should do nothing when config is not set and there is no valid config in the env" do
        expect(Appsignal.internal_logger).to receive(:error)
          .with("Push API key not set after loading config").once
        expect(Appsignal.internal_logger).to receive(:error)
          .with("Not starting, no valid config for this environment").once
        expect(Appsignal::Extension).to_not receive(:start)
        Appsignal.start
      end

      it "should create a config from the env" do
        ENV["APPSIGNAL_PUSH_API_KEY"] = "something"
        expect(Appsignal::Extension).to receive(:start)
        expect(Appsignal.internal_logger).not_to receive(:error)
        silence { Appsignal.start }
        expect(Appsignal.config[:push_api_key]).to eq("something")
      end
    end

    context "when config is loaded" do
      before { Appsignal.config = project_fixture_config }

      it "should initialize logging" do
        Appsignal.start
        expect(Appsignal.internal_logger.level).to eq Logger::INFO
      end

      it "should start native" do
        expect(Appsignal::Extension).to receive(:start)
        Appsignal.start
      end

      context "when allocation tracking has been enabled" do
        before do
          Appsignal.config.config_hash[:enable_allocation_tracking] = true
          capture_environment_metadata_report_calls
        end

        unless DependencyHelper.running_jruby?
          it "installs the allocation event hook" do
            expect(Appsignal::Extension).to receive(:install_allocation_event_hook)
              .and_call_original
            Appsignal.start
            expect_environment_metadata("ruby_allocation_tracking_enabled", "true")
          end
        end
      end

      context "when allocation tracking has been disabled" do
        before do
          Appsignal.config.config_hash[:enable_allocation_tracking] = false
          capture_environment_metadata_report_calls
        end

        it "should not install the allocation event hook" do
          expect(Appsignal::Extension).not_to receive(:install_allocation_event_hook)
          Appsignal.start
          expect_not_environment_metadata("ruby_allocation_tracking_enabled")
        end
      end

      context "when minutely metrics has been enabled" do
        before do
          Appsignal.config.config_hash[:enable_minutely_probes] = true
        end

        it "should start minutely" do
          expect(Appsignal::Minutely).to receive(:start)
          Appsignal.start
        end
      end

      context "when minutely metrics has been disabled" do
        before do
          Appsignal.config.config_hash[:enable_minutely_probes] = false
        end

        it "should not start minutely" do
          expect(Appsignal::Minutely).to_not receive(:start)
          Appsignal.start
        end
      end

      describe "environment metadata" do
        before { capture_environment_metadata_report_calls }

        it "collects and reports environment metadata" do
          Appsignal.start
          expect_environment_metadata("ruby_version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL}")
          expect_environment_metadata("ruby_engine", RUBY_ENGINE)
          if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.3.0")
            expect_environment_metadata("ruby_engine_version", RUBY_ENGINE_VERSION)
          end
        end
      end
    end

    context "with debug logging" do
      before { Appsignal.config = project_fixture_config("test") }

      it "should change the log level" do
        Appsignal.start
        expect(Appsignal.internal_logger.level).to eq Logger::DEBUG
      end
    end
  end

  describe ".forked" do
    context "when not active" do
      it "should should do nothing" do
        expect(Appsignal::Extension).to_not receive(:start)

        Appsignal.forked
      end
    end

    context "when active" do
      before do
        Appsignal.config = project_fixture_config
      end

      it "should resubscribe and start the extension" do
        expect(Appsignal).to receive(:start_logger)
        expect(Appsignal::Extension).to receive(:start)

        Appsignal.forked
      end
    end
  end

  describe ".stop" do
    it "should call stop on the extension" do
      expect(Appsignal.internal_logger).to receive(:debug).with("Stopping appsignal")
      expect(Appsignal::Extension).to receive(:stop)
      Appsignal.stop
      expect(Appsignal.active?).to be_falsy
    end

    context "with context specified" do
      it "should log the context" do
        expect(Appsignal.internal_logger).to receive(:debug).with("Stopping appsignal (something)")
        expect(Appsignal::Extension).to receive(:stop)
        Appsignal.stop("something")
        expect(Appsignal.active?).to be_falsy
      end
    end
  end

  describe ".active?" do
    subject { Appsignal.active? }

    context "without config" do
      before do
        Appsignal.config = nil
      end

      it { is_expected.to be_falsy }
    end

    context "with inactive config" do
      before do
        Appsignal.config = project_fixture_config("nonsense")
      end

      it { is_expected.to be_falsy }
    end

    context "with active config" do
      before do
        Appsignal.config = project_fixture_config
      end

      it { is_expected.to be_truthy }
    end
  end

  describe ".add_exception" do
    it "should alias this method" do
      expect(Appsignal).to respond_to(:add_exception)
    end
  end

  describe ".get_server_state" do
    it "should call server state on the extension" do
      expect(Appsignal::Extension).to receive(:get_server_state).with("key")

      Appsignal.get_server_state("key")
    end

    it "should get nil by default" do
      expect(Appsignal.get_server_state("key")).to be_nil
    end
  end

  context "not active" do
    describe ".monitor_transaction" do
      let(:log_stream) { StringIO.new }
      let(:log) { log_contents(log_stream) }
      before do
        Appsignal.config = project_fixture_config("not_active")
        Appsignal.start
        Appsignal.start_logger
        Appsignal.internal_logger = test_logger(log_stream)
      end
      after { Appsignal.internal_logger = nil }

      it "should do nothing but still yield the block" do
        expect(Appsignal::Transaction).to_not receive(:create)
        expect(Appsignal).to_not receive(:instrument)
        object = double
        expect(object).to receive(:some_method).and_return(1)

        expect do
          expect(Appsignal.monitor_transaction("perform_job.nothing") do
            object.some_method
          end).to eq 1
        end.to_not raise_error
      end

      context "with an unknown event type" do
        it "yields the given block" do
          expect do |blk|
            Appsignal.monitor_transaction("unknown.sidekiq", &blk)
          end.to yield_control
        end

        it "logs an error" do
          Appsignal.monitor_transaction("unknown.sidekiq") {} # rubocop:disable Lint/EmptyBlock
          expect(log).to contains_log(
            :error,
            "Unrecognized name 'unknown.sidekiq': names must start with either 'perform_job' " \
              "(for jobs and tasks) or 'process_action' (for HTTP requests)"
          )
        end
      end
    end

    describe ".listen_for_error" do
      it "does not record anything" do
        error = RuntimeError.new("specific error")
        expect do
          Appsignal.listen_for_error do
            raise error
          end
        end.to raise_error(error)
      end
    end

    describe ".send_error" do
      it "should do nothing" do
        expect do
          Appsignal.send_error(RuntimeError.new)
        end.to_not raise_error
      end
    end

    describe ".set_error" do
      it "should do nothing" do
        expect do
          Appsignal.set_error(RuntimeError.new)
        end.to_not raise_error
      end
    end

    describe ".set_namespace" do
      it "should do nothing" do
        expect do
          Appsignal.set_namespace("custom")
        end.to_not raise_error
      end
    end

    describe ".tag_request" do
      it "should do nothing" do
        expect do
          Appsignal.tag_request(:tag => "tag")
        end.to_not raise_error
      end
    end
  end

  context "with config and started" do
    let(:log_stream) { StringIO.new }
    let(:log) { log_contents(log_stream) }
    before do
      Appsignal.config = project_fixture_config
      Appsignal.start
      Appsignal.start_logger
      Appsignal.internal_logger = test_logger(log_stream)
    end
    after { Appsignal.internal_logger = nil }

    describe ".monitor_transaction" do
      context "with a successful call" do
        it "should instrument and complete for a background job" do
          expect(Appsignal).to receive(:instrument)
            .with("perform_job.something").and_yield
          expect(Appsignal::Transaction).to receive(:complete_current!)
          object = double
          expect(object).to receive(:some_method).and_return(1)

          expect(Appsignal.monitor_transaction(
            "perform_job.something",
            background_env_with_data
          ) do
            current = Appsignal::Transaction.current
            expect(current.namespace).to eq Appsignal::Transaction::BACKGROUND_JOB
            expect(current.request).to be_a(Appsignal::Transaction::GenericRequest)
            object.some_method
          end).to eq 1
        end

        it "should instrument and complete for a http request" do
          expect(Appsignal).to receive(:instrument)
            .with("process_action.something").and_yield
          expect(Appsignal::Transaction).to receive(:complete_current!)
          object = double
          expect(object).to receive(:some_method)

          Appsignal.monitor_transaction(
            "process_action.something",
            http_request_env_with_data
          ) do
            current = Appsignal::Transaction.current
            expect(current.namespace).to eq Appsignal::Transaction::HTTP_REQUEST
            expect(current.request).to be_a(::Rack::Request)
            object.some_method
          end
        end
      end

      context "with an erroring call" do
        let(:error) { ExampleException.new }

        it "should add the error to the current transaction and complete" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
          expect(Appsignal::Transaction).to receive(:complete_current!)

          expect do
            Appsignal.monitor_transaction("perform_job.something") do
              raise error
            end
          end.to raise_error(error)
        end
      end

      context "with an unknown event type" do
        it "yields the given block" do
          expect do |blk|
            Appsignal.monitor_transaction("unknown.sidekiq", &blk)
          end.to yield_control
        end

        it "logs an error" do
          Appsignal.monitor_transaction("unknown.sidekiq") {} # rubocop:disable Lint/EmptyBlock
          expect(log).to contains_log(
            :error,
            "Unrecognized name 'unknown.sidekiq': names must start with either 'perform_job' " \
              "(for jobs and tasks) or 'process_action' (for HTTP requests)"
          )
        end
      end
    end

    describe ".monitor_single_transaction" do
      around { |example| keep_transactions { example.run } }

      context "with a successful call" do
        it "calls monitor_transaction and Appsignal.stop" do
          expect(Appsignal).to receive(:stop)

          Appsignal.monitor_single_transaction(
            "perform_job.something",
            :controller => :my_controller,
            :action => :my_action
          ) do
            # nothing
          end

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "my_controller#my_action"
          )
          expect(transaction_hash["events"]).to match([
            hash_including(
              "name" => "perform_job.something",
              "title" => "",
              "body" => "",
              "body_format" => Appsignal::EventFormatter::DEFAULT
            )
          ])
        end
      end

      context "with an erroring call" do
        let(:error) { ExampleException.new }

        it "calls monitor_transaction and stop and re-raises the error" do
          expect(Appsignal).to receive(:stop)

          expect do
            Appsignal.monitor_single_transaction(
              "perform_job.something",
              :controller => :my_controller,
              :action => :my_action
            ) do
              raise error
            end
          end.to raise_error(error)

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "action" => "my_controller#my_action"
          )
          expect(transaction_hash["events"]).to match([
            hash_including(
              "name" => "perform_job.something",
              "title" => "",
              "body" => "",
              "body_format" => Appsignal::EventFormatter::DEFAULT
            )
          ])
        end
      end
    end

    describe ".tag_request" do
      let(:transaction) { http_request_transaction }
      around do |example|
        start_agent
        with_current_transaction transaction do
          keep_transactions { example.run }
        end
      end

      context "with transaction" do
        it "calls set_tags on the current transaction" do
          Appsignal.tag_request("a" => "b")
          transaction.complete # Manually trigger transaction sampling

          expect(transaction.to_h).to include(
            "sample_data" => hash_including(
              "tags" => { "a" => "b" }
            )
          )
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "should call set_tags on transaction" do
          expect(Appsignal.tag_request).to be_falsy
        end
      end

      it "should also listen to tag_job" do
        expect(Appsignal).to respond_to(:tag_job)
      end
    end

    describe ".add_breadcrumb" do
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      context "with transaction" do
        let(:transaction) { http_request_transaction }
        around do |example|
          Appsignal.config = project_fixture_config
          set_current_transaction transaction do
            example.run
          end
        end

        it "should call add_breadcrumb on transaction" do
          expect(transaction).to receive(:add_breadcrumb)
            .with("Network", "http", "User made network request", { :response => 200 }, fixed_time)
        end

        after do
          Appsignal.add_breadcrumb(
            "Network",
            "http",
            "User made network request",
            { :response => 200 },
            fixed_time
          )
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "should not call add_breadcrumb on transaction" do
          expect(Appsignal.add_breadcrumb("Network", "http")).to be_falsy
        end
      end
    end

    describe "custom stats" do
      let(:tags) { { :foo => "bar" } }

      describe ".set_gauge" do
        it "should call set_gauge on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge("key", 0.1)
        end

        it "should call set_gauge with tags" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          Appsignal.set_gauge("key", 0.1, tags)
        end

        it "should call set_gauge on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:set_gauge)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.set_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:set_gauge).with("key", 10,
            Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("Gauge value 10 for key 'key' is too big")
          expect do
            Appsignal.set_gauge("key", 10)
          end.to_not raise_error
        end
      end

      describe ".set_host_gauge" do
        let(:err_stream) { std_stream }
        let(:stderr) { err_stream.read }
        let(:log_stream) { StringIO.new }
        let(:logs) { log_contents(log_stream) }
        let(:deprecation_message) do
          "The `set_host_gauge` method has been deprecated. " \
            "Calling this method has no effect. " \
            "Please remove method call in the following file to remove " \
            "this message."
        end
        before do
          Appsignal.internal_logger = test_logger(log_stream)
          capture_std_streams(std_stream, err_stream) { Appsignal.set_host_gauge("key", 0.1) }
        end

        it "logs a deprecation warning" do
          expect(stderr).to include("appsignal WARNING: #{deprecation_message}")
          expect(logs).to include(deprecation_message)
        end
      end

      describe ".set_process_gauge" do
        let(:err_stream) { std_stream }
        let(:stderr) { err_stream.read }
        let(:log_stream) { StringIO.new }
        let(:logs) { log_contents(log_stream) }
        let(:deprecation_message) do
          "The `set_process_gauge` method has been deprecated. " \
            "Calling this method has no effect. " \
            "Please remove method call in the following file to remove " \
            "this message."
        end
        before do
          Appsignal.internal_logger = test_logger(log_stream)
          capture_std_streams(std_stream, err_stream) { Appsignal.set_process_gauge("key", 0.1) }
        end

        it "logs a deprecation warning" do
          expect(stderr).to include("appsignal WARNING: #{deprecation_message}")
          expect(logs).to include(deprecation_message)
        end
      end

      describe ".increment_counter" do
        it "should call increment_counter on the extension with a string key" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key")
        end

        it "should call increment_counter with tags" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Utils::Data.generate(tags))
          Appsignal.increment_counter("key", 1, tags)
        end

        it "should call increment_counter on the extension with a symbol key" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 1, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter(:key)
        end

        it "should call increment_counter on the extension with a count" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 5, Appsignal::Extension.data_map_new)
          Appsignal.increment_counter("key", 5)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:increment_counter)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("Counter value 10 for key 'key' is too big")
          expect do
            Appsignal.increment_counter("key", 10)
          end.to_not raise_error
        end
      end

      describe ".add_distribution_value" do
        it "should call add_distribution_value on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value("key", 0.1)
        end

        it "should call add_distribution_value with tags" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 0.1, Appsignal::Utils::Data.generate(tags))
          Appsignal.add_distribution_value("key", 0.1, tags)
        end

        it "should call add_distribution_value on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 1.0, Appsignal::Extension.data_map_new)
          Appsignal.add_distribution_value(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:add_distribution_value)
            .with("key", 10, Appsignal::Extension.data_map_new).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("Distribution value 10 for key 'key' is too big")
          expect do
            Appsignal.add_distribution_value("key", 10)
          end.to_not raise_error
        end
      end
    end

    describe ".internal_logger" do
      subject { Appsignal.internal_logger }

      it { is_expected.to be_a Logger }
    end

    describe ".log_formatter" do
      subject { Appsignal.log_formatter.call("Debug", Time.parse("2015-07-08"), nil, "log line") }

      it "formats a log" do
        expect(subject).to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] log line\n"
      end

      context "with prefix" do
        subject do
          Appsignal.log_formatter("prefix").call("Debug", Time.parse("2015-07-08"), nil, "log line")
        end

        it "adds a prefix" do
          expect(subject)
            .to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] prefix: log line\n"
        end
      end
    end

    describe ".config" do
      subject { Appsignal.config }

      it { is_expected.to be_a Appsignal::Config }
      it "should return configuration" do
        expect(subject[:endpoint]).to eq "https://push.appsignal.com"
      end
    end

    describe ".send_error" do
      let(:transaction) do
        Appsignal::Transaction.new(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          Appsignal::Transaction::GenericRequest.new({})
        )
      end
      let(:error) { ExampleException.new }
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      around { |example| keep_transactions { example.run } }

      it "sends the error to AppSignal" do
        expect(Appsignal::Transaction).to receive(:new).with(
          kind_of(String),
          Appsignal::Transaction::HTTP_REQUEST,
          kind_of(Appsignal::Transaction::GenericRequest)
        ).and_return(transaction)
        expect(transaction).to receive(:set_error).with(error)
        expect(transaction).to_not receive(:set_tags)
        expect(transaction).to receive(:complete)

        Appsignal.send_error(error)
      end

      context "when given error is not an Exception" do
        let(:error) { double }

        it "logs an error message" do
          expect(Appsignal.internal_logger).to receive(:error).with(
            "Appsignal.send_error: Cannot send error. " \
              "The given value is not an exception: #{error.inspect}"
          )
        end

        it "does not send the error" do
          expect(Appsignal::Transaction).to_not receive(:create)
        end

        after { Appsignal.send_error(error) }
      end

      context "with tags" do
        let(:tags) { { :a => "a", :b => "b" } }

        it "prints a deprecation warning and tags the transaction" do
          logs = capture_logs do
            expect do
              capture_std_streams(std_stream, err_stream) do
                Appsignal.send_error(error, tags)
              end
            end.to change { created_transactions.count }.by(1)
          end

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include(
            "sample_data" => hash_including(
              "tags" => { "a" => "a", "b" => "b" }
            )
          )

          message = "The tags argument for `Appsignal.send_error` is deprecated. " \
            "Please use the block method to set tags instead.\n\n" \
            "  Appsignal.send_error(error) do |transaction|\n" \
            "    transaction.set_tags(#{tags.inspect})\n" \
            "  end\n\n" \
            "Appsignal.send_error called on location: #{__FILE__}:"
          expect(stderr).to include("appsignal WARNING: #{message}")
          expect(logs).to include(message)
        end
      end

      context "with namespace" do
        let(:namespace) { "admin" }

        it "prints a deprecation warning and sets the namespace on the transaction" do
          logs = capture_logs do
            expect do
              capture_std_streams(std_stream, err_stream) do
                Appsignal.send_error(error, nil, namespace)
              end
            end.to change { created_transactions.count }.by(1)
          end

          transaction = last_transaction
          transaction_hash = transaction.to_h
          expect(transaction_hash).to include("namespace" => namespace)

          message = "The namespace argument for `Appsignal.send_error` is deprecated. " \
            "Please use the block method to set the namespace instead.\n\n" \
            "  Appsignal.send_error(error) do |transaction|\n" \
            "    transaction.set_namespace(#{namespace.inspect})\n" \
            "  end\n\n" \
            "Appsignal.send_error called on location: #{__FILE__}:"
          expect(stderr).to include("appsignal WARNING: #{message}")
          expect(logs).to include(message)
        end
      end

      context "when given a block" do
        it "yields the transaction and allows additional metadata to be set" do
          captured_transaction = nil
          keep_transactions do
            Appsignal.send_error(StandardError.new("my_error")) do |transaction|
              captured_transaction = transaction
              transaction.set_action("my_action")
              transaction.set_namespace("my_namespace")
            end
          end
          expect(captured_transaction.to_h).to include(
            "namespace" => "my_namespace",
            "action" => "my_action",
            "error" => {
              "name" => "StandardError",
              "message" => "my_error",
              "backtrace" => kind_of(String) # TODO: should be Array
            }
          )
        end
      end
    end

    describe ".listen_for_error" do
      around { |example| keep_transactions { example.run } }

      it "records the error and re-raise it" do
        expect do
          expect do
            Appsignal.listen_for_error do
              raise ExampleException, "I am an exception"
            end
          end.to raise_error(ExampleException, "I am an exception")
        end.to change { created_transactions.count }.by(1)

        expect(last_transaction.to_h).to include(
          "error" => {
            "name" => "ExampleException",
            "message" => "I am an exception",
            "backtrace" => kind_of(String)
          },
          "namespace" => Appsignal::Transaction::HTTP_REQUEST, # Default namespace
          "sample_data" => hash_including(
            "tags" => {}
          )
        )
      end

      context "with tags" do
        it "adds tags to the transaction" do
          expect do
            expect do
              Appsignal.listen_for_error("foo" => "bar") do
                raise ExampleException, "I am an exception"
              end
            end.to raise_error(ExampleException, "I am an exception")
          end.to change { created_transactions.count }.by(1)

          expect(last_transaction.to_h).to include(
            "error" => {
              "name" => "ExampleException",
              "message" => "I am an exception",
              "backtrace" => kind_of(String)
            },
            "namespace" => Appsignal::Transaction::HTTP_REQUEST, # Default namespace
            "sample_data" => hash_including(
              "tags" => { "foo" => "bar" }
            )
          )
        end
      end

      context "with a custom namespace" do
        it "adds the namespace to the transaction" do
          expect do
            expect do
              Appsignal.listen_for_error(nil, "custom_namespace") do
                raise ExampleException, "I am an exception"
              end
            end.to raise_error(ExampleException, "I am an exception")
          end.to change { created_transactions.count }.by(1)

          expect(last_transaction.to_h).to include(
            "error" => {
              "name" => "ExampleException",
              "message" => "I am an exception",
              "backtrace" => kind_of(String)
            },
            "namespace" => "custom_namespace",
            "sample_data" => hash_including(
              "tags" => {}
            )
          )
        end
      end
    end

    describe ".set_error" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:error) { ExampleException.new("I am an exception") }
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }
      around { |example| keep_transactions { example.run } }

      context "when there is an active transaction" do
        it "adds the error to the active transaction" do
          expect(transaction).to receive(:set_error).with(error)
          expect(transaction).to_not receive(:set_tags)
          expect(transaction).to_not receive(:set_namespace)

          Appsignal.set_error(error)
        end

        context "when the error is not an Exception" do
          let(:error) { Object.new }

          it "logs an error" do
            expect(Appsignal.internal_logger).to receive(:error).with(
              "Appsignal.set_error: Cannot set error. " \
                "The given value is not an exception: #{error.inspect}"
            )
            expect(transaction).to_not receive(:set_error)
            expect(transaction).to_not receive(:set_tags)
            expect(transaction).to_not receive(:set_namespace)

            Appsignal.set_error(error)
          end
        end

        context "with tags" do
          let(:tags) { { "foo" => "bar" } }

          it "prints a deprecation warning and tags the transaction" do
            expect(transaction).to receive(:set_error).with(error)
            expect(transaction).to receive(:set_tags).with(tags)
            expect(transaction).to_not receive(:set_namespace)

            logs = capture_logs do
              capture_std_streams(std_stream, err_stream) do
                Appsignal.set_error(error, tags)
              end
            end

            message = "The tags argument for `Appsignal.set_error` is deprecated. " \
              "Please use the block method to set tags instead.\n\n" \
              "  Appsignal.set_error(error) do |transaction|\n" \
              "    transaction.set_tags(#{tags.inspect})\n" \
              "  end\n\n" \
              "Appsignal.set_error called on location: #{__FILE__}:"
            expect(stderr).to include("appsignal WARNING: #{message}")
            expect(logs).to include(message)
          end
        end

        context "with namespace" do
          let(:namespace) { "admin" }

          it "prints a deprecation warning andsets the namespace on the transaction" do
            expect(transaction).to receive(:set_error).with(error)
            expect(transaction).to_not receive(:set_tags)
            expect(transaction).to receive(:set_namespace).with(namespace)

            logs = capture_logs do
              capture_std_streams(std_stream, err_stream) do
                Appsignal.set_error(error, nil, namespace)
              end
            end

            message = "The namespace argument for `Appsignal.set_error` is deprecated. " \
              "Please use the block method to set the namespace instead.\n\n" \
              "  Appsignal.set_error(error) do |transaction|\n" \
              "    transaction.set_namespace(#{namespace.inspect})\n" \
              "  end\n\n" \
              "Appsignal.set_error called on location: #{__FILE__}:"
            expect(stderr).to include("appsignal WARNING: #{message}")
            expect(logs).to include(message)
          end
        end

        context "when given a block" do
          it "yields the transaction and allows additional metadata to be set" do
            captured_transaction = nil
            keep_transactions do
              Appsignal.set_error(StandardError.new("my_error")) do |transaction|
                captured_transaction = transaction
                transaction.set_action("my_action")
                transaction.set_namespace("my_namespace")
              end
            end

            expect(transaction).to eql(captured_transaction)
            expect(captured_transaction.to_h).to include(
              "namespace" => "my_namespace",
              "action" => "my_action",
              "error" => {
                "name" => "StandardError",
                "message" => "my_error",
                "backtrace" => kind_of(String)
              }
            )
          end
        end
      end

      context "when there is no active transaction" do
        it "does nothing" do
          allow(Appsignal::Transaction).to receive(:current).and_return(nil)

          expect(transaction).to_not receive(:set_error)

          Appsignal.set_error(error)
        end
      end
    end

    describe ".set_action" do
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      it "should set the namespace to the current transaction" do
        expect(transaction).to receive(:set_action).with("custom")

        Appsignal.set_action("custom")
      end

      it "should do nothing if there is no current transaction" do
        allow(Appsignal::Transaction).to receive(:current).and_return(nil)

        expect(transaction).to_not receive(:set_action)

        Appsignal.set_action("custom")
      end

      it "should do nothing if the error is nil" do
        expect(transaction).to_not receive(:set_action)

        Appsignal.set_action(nil)
      end
    end

    describe ".set_namespace" do
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      it "should set the namespace to the current transaction" do
        expect(transaction).to receive(:set_namespace).with("custom")

        Appsignal.set_namespace("custom")
      end

      it "should do nothing if there is no current transaction" do
        allow(Appsignal::Transaction).to receive(:current).and_return(nil)

        expect(transaction).to_not receive(:set_namespace)

        Appsignal.set_namespace("custom")
      end

      it "should do nothing if the error is nil" do
        expect(transaction).to_not receive(:set_namespace)

        Appsignal.set_namespace(nil)
      end
    end

    describe ".instrument" do
      it_behaves_like "instrument helper" do
        let(:instrumenter) { Appsignal }
        before do
          expect(Appsignal::Transaction).to receive(:current).at_least(:once)
            .and_return(transaction)
        end
      end
    end

    describe ".instrument_sql" do
      before do
        expect(Appsignal::Transaction).to receive(:current).at_least(:once)
          .and_return(transaction)
      end

      it "creates an SQL event on the transaction" do
        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event)
          .with("name", "title", "body", Appsignal::EventFormatter::SQL_BODY_FORMAT)

        result = Appsignal.instrument_sql "name", "title", "body" do
          "return value"
        end
        expect(result).to eq "return value"
      end
    end

    describe ".without_instrumentation" do
      let(:transaction) { http_request_transaction }
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      it "does not record events on the transaction" do
        expect(transaction).to receive(:pause!).and_call_original
        expect(transaction).to receive(:resume!).and_call_original
        Appsignal.instrument("register.this.event") { :do_nothing }
        Appsignal.without_instrumentation do
          Appsignal.instrument("dont.register.this.event") { :do_nothing }
        end
        expect(transaction.to_h["events"].map { |e| e["name"] })
          .to match_array("register.this.event")
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "should not crash" do
          Appsignal.without_instrumentation { :do_nothing }
        end
      end
    end
  end

  describe ".start_logger" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:log_path) { File.join(tmp_dir, "log") }
    let(:log_file) { File.join(log_path, "appsignal.log") }

    before { FileUtils.mkdir_p(log_path) }
    after { FileUtils.rm_rf(log_path) }

    def initialize_config
      Appsignal.config = project_fixture_config(
        "production",
        :log_path => log_path
      )
      Appsignal.internal_logger.error("Log in memory")
    end

    context "when the log path is writable" do
      context "when the log file is writable" do
        let(:log_file_contents) { File.read(log_file) }

        before do
          capture_stdout(out_stream) do
            initialize_config
            Appsignal.start_logger
            Appsignal.internal_logger.error("Log to file")
          end
          expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
        end

        it "logs to file" do
          expect(File.exist?(log_file)).to be_truthy
          expect(log_file_contents).to include "[ERROR] Log to file"
          expect(output).to be_empty
        end

        it "amends in memory log to log file" do
          expect(log_file_contents).to include "[ERROR] appsignal: Log in memory"
        end
      end

      context "when the log file is not writable" do
        before do
          FileUtils.touch log_file
          FileUtils.chmod 0o444, log_file

          capture_stdout(out_stream) do
            initialize_config
            Appsignal.start_logger
            Appsignal.internal_logger.error("Log to not writable log file")
            expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
          end
        end

        it "logs to stdout" do
          expect(File.writable?(log_file)).to be_falsy
          expect(output).to include "[ERROR] appsignal: Log to not writable log file"
        end

        it "amends in memory log to stdout" do
          expect(output).to include "[ERROR] appsignal: Log in memory"
        end

        it "outputs a warning" do
          puts output
          expect(output).to include \
            "[WARN] appsignal: Unable to start internal logger with log path '#{log_file}'.",
            "[WARN] appsignal: Permission denied"
        end
      end
    end

    context "when the log path and fallback path are not writable" do
      before do
        FileUtils.chmod 0o444, log_path
        FileUtils.chmod 0o444, Appsignal::Config.system_tmp_dir

        capture_stdout(out_stream) do
          initialize_config
          Appsignal.start_logger
          Appsignal.internal_logger.error("Log to not writable log path")
        end
        expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
      end
      after do
        FileUtils.chmod 0o755, Appsignal::Config.system_tmp_dir
      end

      it "logs to stdout" do
        expect(File.writable?(log_path)).to be_falsy
        expect(output).to include "[ERROR] appsignal: Log to not writable log path"
      end

      it "amends in memory log to stdout" do
        expect(output).to include "[ERROR] appsignal: Log in memory"
      end

      it "outputs a warning" do
        expect(output).to include \
          "appsignal: Unable to log to '#{log_path}' " \
            "or the '#{Appsignal::Config.system_tmp_dir}' fallback."
      end
    end

    context "when on Heroku" do
      before do
        capture_stdout(out_stream) do
          initialize_config
          Appsignal.start_logger
          Appsignal.internal_logger.error("Log to stdout")
        end
        expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
      end
      around { |example| recognize_as_heroku { example.run } }

      it "logs to stdout" do
        expect(output).to include "[ERROR] appsignal: Log to stdout"
      end

      it "amends in memory log to stdout" do
        expect(output).to include "[ERROR] appsignal: Log in memory"
      end
    end

    describe "#logger#level" do
      subject { Appsignal.internal_logger.level }

      context "when there is no config" do
        before do
          Appsignal.config = nil
          capture_stdout(out_stream) do
            Appsignal.start_logger
          end
        end

        it "sets the log level to info" do
          expect(subject).to eq Logger::INFO
        end
      end

      context "when there is a config" do
        context "when log level is configured to debug" do
          before do
            capture_stdout(out_stream) do
              initialize_config
              Appsignal.config[:log_level] = "debug"
              Appsignal.start_logger
            end
          end

          it "sets the log level to debug" do
            expect(subject).to eq Logger::DEBUG
          end
        end
      end
    end
  end
end
