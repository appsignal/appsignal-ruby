describe Appsignal do
  include EnvironmentMetadataHelper
  around { |example| keep_transactions { example.run } }

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
      let(:stdout_stream) { std_stream }
      let(:stdout) { stdout_stream.read }
      let(:stderr_stream) { std_stream }
      let(:stderr) { stderr_stream.read }
      before { ENV["APPSIGNAL_LOG"] = "stdout" }

      it "does nothing when config is not set and there is no valid config in the env" do
        expect(Appsignal::Extension).to_not receive(:start)
        capture_std_streams(stdout_stream, stderr_stream) { Appsignal.start }

        expect(stdout).to contains_log(
          :error,
          "appsignal: Not starting, no valid config for this environment"
        )
      end

      it "should create a config from the env" do
        ENV["APPSIGNAL_PUSH_API_KEY"] = "something"
        expect(Appsignal::Extension).to receive(:start)
        capture_std_streams(stdout_stream, stderr_stream) { Appsignal.start }

        expect(Appsignal.config[:push_api_key]).to eq("something")
        expect(stderr).to_not include("[ERROR]")
        expect(stdout).to_not include("[ERROR]")
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
          expect(Appsignal::Probes).to receive(:start)
          Appsignal.start
        end
      end

      context "when minutely metrics has been disabled" do
        before do
          Appsignal.config.config_hash[:enable_minutely_probes] = false
        end

        it "should not start minutely" do
          expect(Appsignal::Probes).to_not receive(:start)
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
      it "does nothing" do
        expect(Appsignal::Extension).to_not receive(:start)

        Appsignal.forked
      end
    end

    context "when active" do
      before do
        Appsignal.config = project_fixture_config
      end

      it "starts the logger and extension" do
        expect(Appsignal).to receive(:_start_logger)
        expect(Appsignal::Extension).to receive(:start)

        Appsignal.forked
      end
    end
  end

  describe ".stop" do
    it "calls stop on the extension" do
      expect(Appsignal.internal_logger).to receive(:debug).with("Stopping appsignal")
      expect(Appsignal::Extension).to receive(:stop)
      Appsignal.stop
      expect(Appsignal.active?).to be_falsy
    end

    it "stops the minutely probes" do
      Appsignal::Probes.start
      expect(Appsignal::Probes.started?).to be_truthy
      Appsignal.stop
      expect(Appsignal::Probes.started?).to be_falsy
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
    before { Appsignal.config = project_fixture_config("not_active") }

    describe ".monitor_transaction" do
      it "does not create a transaction" do
        object = double(:some_method => 1)

        expect do
          Appsignal.monitor_transaction("perform_job.nothing") do
            object.some_method
          end
        end.to_not(change { created_transactions.count })
      end

      it "returns the block's return value" do
        object = double(:some_method => 1)

        return_value = Appsignal.monitor_transaction("perform_job.nothing") do
          object.some_method
        end
        expect(return_value).to eq 1
      end

      context "with an unknown event type" do
        it "yields the given block" do
          expect do |blk|
            Appsignal.monitor_transaction("unknown.sidekiq", &blk)
          end.to yield_control
        end

        it "logs an error" do
          logs =
            capture_logs do
              Appsignal.monitor_transaction("unknown.sidekiq") {} # rubocop:disable Lint/EmptyBlock
            end
          expect(logs).to contains_log(
            :error,
            "Unrecognized name 'unknown.sidekiq': names must start with either 'perform_job' " \
              "(for jobs and tasks) or 'process_action' (for HTTP requests)"
          )
        end
      end
    end

    describe ".listen_for_error" do
      let(:error) { ExampleException.new("specific error") }

      it "reraises the error" do
        expect do
          Appsignal.listen_for_error { raise error }
        end.to raise_error(error)
      end

      it "does not create a transaction" do
        expect do
          expect do
            Appsignal.listen_for_error { raise error }
          end.to raise_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".send_error" do
      let(:error) { ExampleException.new("specific error") }

      it "does not raise an error" do
        Appsignal.send_error(error)
      end

      it "does not create a transaction" do
        expect do
          Appsignal.send_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".set_error" do
      let(:error) { ExampleException.new("specific error") }

      it "does not raise an error" do
        Appsignal.set_error(error)
      end

      it "does not create a transaction" do
        expect do
          Appsignal.set_error(error)
        end.to_not(change { created_transactions.count })
      end
    end

    describe ".set_namespace" do
      it "does not raise an error" do
        Appsignal.set_namespace("custom")
      end
    end

    describe ".tag_request" do
      it "does not raise an error" do
        Appsignal.tag_request(:tag => "tag")
      end
    end
  end

  context "with config and started" do
    before { start_agent }
    around { |example| keep_transactions { example.run } }

    describe ".monitor_transaction" do
      context "with a successful call" do
        it "instruments and completes for a background job" do
          return_value = nil
          expect do
            return_value =
              Appsignal.monitor_transaction(
                "perform_job.something",
                {
                  :class => "BackgroundJob",
                  :method => "perform"
                }
              ) do
                :return_value
              end
          end.to(change { created_transactions.count }.by(1))
          expect(return_value).to eq(:return_value)

          transaction = last_transaction
          expect(transaction).to have_namespace(Appsignal::Transaction::BACKGROUND_JOB)
          expect(transaction).to have_action("BackgroundJob#perform")
          expect(transaction).to include_event("name" => "perform_job.something")
          expect(transaction).to be_completed
        end

        it "instruments and completes for a http request" do
          return_value = nil
          expect do
            return_value =
              Appsignal.monitor_transaction(
                "process_action.something",
                {
                  :controller => "BlogPostsController",
                  :action => "show"
                }
              ) do
                :return_value
              end
          end.to(change { created_transactions.count }.by(1))
          expect(return_value).to eq(:return_value)

          transaction = last_transaction
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_action("BlogPostsController#show")
          expect(transaction).to include_event("name" => "process_action.something")
          expect(transaction).to be_completed
        end
      end

      context "with an erroring call" do
        let(:error) { ExampleException.new("error message") }

        it "adds the error to the current transaction and complete" do
          expect do
            Appsignal.monitor_transaction("perform_job.something") do
              raise error
            end
          end.to raise_error(error)

          expect(last_transaction).to have_error("ExampleException", "error message")
          expect(last_transaction).to be_completed
        end
      end

      context "with an unknown event type" do
        it "yields the given block" do
          expect do |blk|
            Appsignal.monitor_transaction("unknown.sidekiq", &blk)
          end.to yield_control
        end

        it "logs an error" do
          logs =
            capture_logs do
              Appsignal.monitor_transaction("unknown.sidekiq") {} # rubocop:disable Lint/EmptyBlock
            end
          expect(logs).to contains_log(
            :error,
            "Unrecognized name 'unknown.sidekiq': names must start with either 'perform_job' " \
              "(for jobs and tasks) or 'process_action' (for HTTP requests)"
          )
        end
      end
    end

    describe ".monitor_single_transaction" do
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
          expect(transaction).to have_action("my_controller#my_action")
          expect(transaction).to include_event("name" => "perform_job.something")
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
          expect(transaction).to have_action("my_controller#my_action")
          expect(transaction).to include_event("name" => "perform_job.something")
        end
      end
    end

    describe ".tag_request" do
      around do |example|
        start_agent
        with_current_transaction(transaction) { example.run }
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        it "calls set_tags on the current transaction" do
          Appsignal.tag_request("a" => "b")

          transaction._sample
          expect(transaction).to include_tags("a" => "b")
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "does not set tags on the transaction" do
          expect(Appsignal.tag_request).to be_falsy
          Appsignal.tag_request("a" => "b")

          expect_any_instance_of(Appsignal::Transaction).to_not receive(:set_tags)
        end
      end

      it "also listens to tag_job" do
        expect(Appsignal).to respond_to(:tag_job)
      end
    end

    describe ".add_breadcrumb" do
      around do |example|
        start_agent
        with_current_transaction(transaction) { example.run }
      end

      context "with transaction" do
        let(:transaction) { http_request_transaction }

        it "adds the breadcrumb to the transaction" do
          Appsignal.add_breadcrumb(
            "Network",
            "http",
            "User made network request",
            { :response => 200 },
            fixed_time
          )

          transaction._sample
          expect(transaction).to include_breadcrumb(
            "http",
            "Network",
            "User made network request",
            { "response" => 200 },
            fixed_time
          )
        end
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "does not add a breadcrumb to any transaction" do
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
          expect(Appsignal::Extension).to receive(:set_gauge).with(
            "key",
            10,
            Appsignal::Extension.data_map_new
          ).and_raise(RangeError)
          expect(Appsignal.internal_logger).to receive(:warn)
            .with("Gauge value 10 for key 'key' is too big")

          Appsignal.set_gauge("key", 10)
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

          Appsignal.increment_counter("key", 10)
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

          Appsignal.add_distribution_value("key", 10)
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
      let(:error) { ExampleException.new("error message") }
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      around do |example|
        keep_transactions { example.run }
      end

      it "sends the error to AppSignal" do
        expect { Appsignal.send_error(error) }.to(change { created_transactions.count }.by(1))

        transaction = last_transaction
        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction).to_not have_action
        expect(transaction).to have_error("ExampleException", "error message")
        expect(transaction).to_not include_tags
        expect(transaction).to be_completed
      end

      context "when given error is not an Exception" do
        let(:error) { "string value" }

        it "logs an error message" do
          logs = capture_logs { Appsignal.send_error(error) }
          expect(logs).to contains_log(
            :error,
            "Appsignal.send_error: Cannot send error. " \
              "The given value is not an exception: #{error.inspect}"
          )
        end

        it "does not send the error" do
          expect { Appsignal.send_error(error) }.to_not(change { created_transactions.count })
        end
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

          expect(last_transaction).to include_tags("a" => "a", "b" => "b")

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

          expect(last_transaction).to have_namespace(namespace)

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
          keep_transactions do
            Appsignal.send_error(StandardError.new("my_error")) do |transaction|
              transaction.set_action("my_action")
              transaction.set_namespace("my_namespace")
            end
          end
          expect(last_transaction).to have_namespace("my_namespace")
          expect(last_transaction).to have_action("my_action")
          expect(last_transaction).to have_error("StandardError", "my_error")
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

        # Default namespace
        expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        expect(last_transaction).to have_error("ExampleException", "I am an exception")
        expect(last_transaction).to_not include_tags
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

          # Default namespace
          expect(last_transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(last_transaction).to have_error("ExampleException", "I am an exception")
          expect(last_transaction).to include_tags("foo" => "bar")
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

          # Default namespace
          expect(last_transaction).to have_namespace("custom_namespace")
          expect(last_transaction).to have_error("ExampleException", "I am an exception")
          expect(last_transaction).to_not include_tags
        end
      end
    end

    describe ".set_error" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:error) { ExampleException.new("I am an exception") }
      let(:transaction) { http_request_transaction }
      around { |example| keep_transactions { example.run } }

      context "when there is an active transaction" do
        before { set_current_transaction(transaction) }

        it "adds the error to the active transaction" do
          Appsignal.set_error(error)

          transaction._sample
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
          expect(transaction).to have_error("ExampleException", "I am an exception")
          expect(transaction).to_not include_tags
        end

        context "when the error is not an Exception" do
          let(:error) { Object.new }

          it "does not set an error" do
            silence { Appsignal.set_error(error) }

            transaction._sample
            expect(transaction).to_not have_error
            expect(transaction).to_not include_tags
          end

          it "logs an error" do
            logs = capture_logs { Appsignal.set_error(error) }
            expect(logs).to contains_log(
              :error,
              "Appsignal.set_error: Cannot set error. " \
                "The given value is not an exception: #{error.inspect}"
            )
          end
        end

        context "with tags" do
          let(:tags) { { "foo" => "bar" } }

          it "tags the transaction" do
            silence(:allowed => ["set_error", "The tags argument for"]) do
              Appsignal.set_error(error, tags)
            end

            transaction._sample
            expect(transaction).to have_error(error)
            expect(transaction).to include_tags(tags)
          end

          it "prints a deprecation warning and tags the transaction" do
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

          it "sets the namespace on the transaction" do
            silence(:allowed => ["set_error", "The namespace argument for"]) do
              Appsignal.set_error(error, nil, namespace)
            end

            expect(transaction).to have_error("ExampleException", "I am an exception")
            expect(transaction).to have_namespace(namespace)
            expect(transaction).to_not include_tags
          end

          it "prints a deprecation warning andsets the namespace on the transaction" do
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
            Appsignal.set_error(StandardError.new("my_error")) do |t|
              t.set_action("my_action")
              t.set_namespace("my_namespace")
            end

            expect(transaction).to have_namespace("my_namespace")
            expect(transaction).to have_action("my_action")
            expect(transaction).to have_error("StandardError", "my_error")
          end
        end
      end

      context "when there is no active transaction" do
        it "does nothing" do
          Appsignal.set_error(error)

          expect(transaction).to_not have_error
        end
      end
    end

    describe ".set_action" do
      around { |example| keep_transactions { example.run } }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "sets the namespace on the current transaction" do
          Appsignal.set_action("custom")

          expect(transaction).to have_action("custom")
        end

        it "does not set the action if the action is nil" do
          Appsignal.set_action(nil)

          expect(transaction).to_not have_action
        end
      end

      context "without current transaction" do
        it "does not set ther action" do
          Appsignal.set_action("custom")

          expect(transaction).to_not have_action
        end
      end
    end

    describe ".set_namespace" do
      around { |example| keep_transactions { example.run } }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "should set the namespace to the current transaction" do
          Appsignal.set_namespace("custom")

          expect(transaction).to have_namespace("custom")
        end

        it "does not update the namespace if the namespace is nil" do
          Appsignal.set_namespace(nil)

          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end
      end

      context "without current transaction" do
        it "does not update the namespace" do
          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)

          Appsignal.set_namespace("custom")

          expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
        end
      end
    end

    describe ".instrument" do
      it_behaves_like "instrument helper" do
        let(:instrumenter) { Appsignal }
        before { set_current_transaction(transaction) }
      end
    end

    describe ".instrument_sql" do
      around { |example| keep_transactions { example.run } }
      before { set_current_transaction(transaction) }

      it "creates an SQL event on the transaction" do
        result =
          Appsignal.instrument_sql "name", "title", "body" do
            "return value"
          end

        expect(result).to eq "return value"
        expect(transaction).to include_event(
          "name" => "name",
          "title" => "title",
          "body" => "body",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
        )
      end
    end

    describe ".without_instrumentation" do
      around { |example| keep_transactions { example.run } }
      let(:transaction) { http_request_transaction }

      context "with current transaction" do
        before { set_current_transaction(transaction) }

        it "does not record events on the transaction" do
          expect(transaction).to receive(:pause!).and_call_original
          expect(transaction).to receive(:resume!).and_call_original

          Appsignal.instrument("register.this.event") { :do_nothing }
          Appsignal.without_instrumentation do
            Appsignal.instrument("dont.register.this.event") { :do_nothing }
          end

          expect(transaction).to include_event("name" => "register.this.event")
          expect(transaction).to_not include_event("name" => "dont.register.this.event")
        end
      end

      context "without current transaction" do
        let(:transaction) { nil }

        it "does not crash" do
          Appsignal.without_instrumentation { :do_nothing }
        end
      end
    end
  end

  describe ".start_logger" do
    let(:stderr_stream) { std_stream }
    let(:stderr) { stderr_stream.read }
    let(:log_stream) { std_stream }
    let(:log) { log_contents(log_stream) }

    it "prints and logs a deprecation warning" do
      use_logger_with(log_stream) do
        capture_std_streams(std_stream, stderr_stream) do
          Appsignal.start_logger
        end
      end
      expect(stderr).to include("appsignal WARNING: Callng 'Appsignal.start_logger' is deprecated.")
      expect(log).to contains_log(:warn, "Callng 'Appsignal.start_logger' is deprecated.")
    end
  end

  describe "._start_logger" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:log_path) { File.join(tmp_dir, "log") }
    let(:log_file) { File.join(log_path, "appsignal.log") }
    let(:log_level) { "debug" }

    before do
      FileUtils.mkdir_p(log_path)
      # Clear state from previous test
      Appsignal.internal_logger = nil
      if Appsignal.instance_variable_defined?(:@in_memory_logger)
        Appsignal.remove_instance_variable(:@in_memory_logger)
      end
    end
    after { FileUtils.rm_rf(log_path) }

    def initialize_config
      Appsignal.config = project_fixture_config(
        "production",
        :log_path => log_path,
        :log_level => log_level
      )
      Appsignal.internal_logger.error("Log in memory line 1")
      Appsignal.internal_logger.debug("Log in memory line 2")
      expect(Appsignal.in_memory_logger.messages).to_not be_empty
    end

    context "when the log path is writable" do
      context "when the log file is writable" do
        let(:log_file_contents) { File.read(log_file) }

        before do
          capture_stdout(out_stream) do
            initialize_config
            Appsignal._start_logger
            Appsignal.internal_logger.error("Log to file")
          end
          expect(Appsignal.internal_logger).to be_a(Appsignal::Utils::IntegrationLogger)
        end

        it "logs to file" do
          expect(File.exist?(log_file)).to be_truthy
          expect(log_file_contents).to include "[ERROR] Log to file"
          expect(output).to be_empty
        end

        context "with log level info" do
          let(:log_level) { "info" }

          it "amends info log level and higher memory log messages to log file" do
            expect(log_file_contents).to include "[ERROR] appsignal: Log in memory line 1"
            expect(log_file_contents).to_not include "[DEBUG]"
          end
        end

        context "with log level debug" do
          let(:log_level) { "debug" }

          it "amends debug log level and higher memory log messages to log file" do
            expect(log_file_contents).to include "[ERROR] appsignal: Log in memory line 1"
            expect(log_file_contents).to include "[DEBUG] appsignal: Log in memory line 2"
          end
        end

        it "clears the in memory log after writing to the new logger" do
          expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
        end
      end

      context "when the log file is not writable" do
        before do
          FileUtils.touch log_file
          FileUtils.chmod 0o444, log_file

          capture_stdout(out_stream) do
            initialize_config
            Appsignal._start_logger
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

        it "clears the in memory log after writing to the new logger" do
          expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
        end

        it "outputs a warning" do
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
          Appsignal._start_logger
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
          Appsignal._start_logger
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

      it "clears the in memory log after writing to the new logger" do
        expect(Appsignal.instance_variable_get(:@in_memory_logger)).to be_nil
      end
    end

    describe "#logger#level" do
      subject { Appsignal.internal_logger.level }

      context "when there is no config" do
        before do
          Appsignal.config = nil
          capture_stdout(out_stream) do
            Appsignal._start_logger
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
              Appsignal._start_logger
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
