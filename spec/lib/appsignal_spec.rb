describe Appsignal do
  before do
    # Make sure we have a clean state because we want to test
    # initialization here.
    Appsignal.config = nil
    Appsignal.extensions.clear
  end

  let(:transaction) { http_request_transaction }

  describe ".config=" do
    it "should set the config" do
      config = project_fixture_config
      expect(Appsignal.logger).to_not receive(:level=)

      Appsignal.config = config
      expect(Appsignal.config).to eq config
    end
  end

  describe ".extensions" do
    it "should keep a list of extensions" do
      expect(Appsignal.extensions).to be_empty
      Appsignal.extensions << Appsignal::MockExtension
      expect(Appsignal.extensions.size).to eq(1)
    end
  end

  describe ".start" do
    context "with no config set beforehand" do
      it "should do nothing when config is not set and there is no valid config in the env" do
        expect(Appsignal.logger).to receive(:error).with(
          "Push api key not set after loading config"
        ).once
        expect(Appsignal.logger).to receive(:error).with(
          "Not starting, no valid config for this environment"
        ).once
        expect(Appsignal::Extension).to_not receive(:start)
        Appsignal.start
      end

      it "should create a config from the env" do
        ENV["APPSIGNAL_PUSH_API_KEY"] = "something"
        expect(Appsignal::Extension).to receive(:start)
        expect(Appsignal.logger).not_to receive(:error)
        silence { Appsignal.start }
        expect(Appsignal.config[:push_api_key]).to eq("something")
      end
    end

    context "when config is loaded" do
      before { Appsignal.config = project_fixture_config }

      it "should initialize logging" do
        Appsignal.start
        expect(Appsignal.logger.level).to eq Logger::INFO
      end

      it "should start native" do
        expect(Appsignal::Extension).to receive(:start)
        Appsignal.start
      end

      it "should initialize formatters" do
        expect(Appsignal::EventFormatter).to receive(:initialize_formatters)
        Appsignal.start
      end

      context "with an extension" do
        before { Appsignal.extensions << Appsignal::MockExtension }

        it "should call the extension's initializer" do
          expect(Appsignal::MockExtension).to receive(:initializer)
          Appsignal.start
        end
      end

      context "when allocation tracking and gc instrumentation have been enabled" do
        before do
          allow(GC::Profiler).to receive(:enable)
          Appsignal.config.config_hash[:enable_allocation_tracking] = true
          Appsignal.config.config_hash[:enable_gc_instrumentation] = true
        end

        it "should enable Ruby's GC::Profiler" do
          expect(GC::Profiler).to receive(:enable)
          Appsignal.start
        end

        it "should install the allocation event hook" do
          expect(Appsignal::Extension).to receive(:install_allocation_event_hook)
          Appsignal.start
        end

        it "should add the gc probe to minutely" do
          expect(Appsignal::Minutely).to receive(:add_gc_probe)
          Appsignal.start
        end
      end

      context "when allocation tracking and gc instrumentation have been disabled" do
        before do
          Appsignal.config.config_hash[:enable_allocation_tracking] = false
          Appsignal.config.config_hash[:enable_gc_instrumentation] = false
        end

        it "should not enable Ruby's GC::Profiler" do
          expect(GC::Profiler).not_to receive(:enable)
          Appsignal.start
        end

        it "should not install the allocation event hook" do
          expect(Appsignal::Minutely).not_to receive(:install_allocation_event_hook)
          Appsignal.start
        end

        it "should not add the gc probe to minutely" do
          expect(Appsignal::Minutely).not_to receive(:add_gc_probe)
          Appsignal.start
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
    end

    context "with debug logging" do
      before { Appsignal.config = project_fixture_config("test") }

      it "should change the log level" do
        Appsignal.start
        expect(Appsignal.logger.level).to eq Logger::DEBUG
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
      expect(Appsignal.logger).to receive(:debug).with("Stopping appsignal")
      expect(Appsignal::Extension).to receive(:stop)
      Appsignal.stop
      expect(Appsignal.active?).to be_falsy
    end

    context "with context specified" do
      it "should log the context" do
        expect(Appsignal.logger).to receive(:debug).with("Stopping appsignal (something)")
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
    end

    describe ".listen_for_error" do
      it "should do nothing" do
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

    describe ".instrument" do
      it "should not instrument, but still call the block" do
        stub = double
        expect(stub).to receive(:method_call).and_return("return value")

        return_value = Appsignal.instrument "name" do
          stub.method_call
        end
        expect(return_value).to eq "return value"
      end
    end
  end

  context "with config and started" do
    before do
      Appsignal.config = project_fixture_config
      Appsignal.start
    end

    describe ".monitor_transaction" do
      context "with a successful call" do
        it "should instrument and complete for a background job" do
          expect(Appsignal).to receive(:instrument).with(
            "perform_job.something"
          ).and_yield
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
          expect(Appsignal).to receive(:instrument).with(
            "process_action.something"
          ).and_yield
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
        let(:error) { VerySpecificError.new }

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
    end

    describe ".monitor_single_transaction" do
      context "with a successful call" do
        it "should call monitor_transaction and stop" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.something",
            :key => :value
          ).and_yield
          expect(Appsignal).to receive(:stop)

          Appsignal.monitor_single_transaction("perform_job.something", :key => :value) do
            # nothing
          end
        end
      end

      context "with an erroring call" do
        let(:error) { VerySpecificError.new }

        it "should call monitor_transaction and stop and then raise the error" do
          expect(Appsignal).to receive(:monitor_transaction).with(
            "perform_job.something",
            :key => :value
          ).and_yield
          expect(Appsignal).to receive(:stop)

          expect do
            Appsignal.monitor_single_transaction("perform_job.something", :key => :value) do
              raise error
            end
          end.to raise_error(error)
        end
      end
    end

    describe ".tag_request" do
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      context "with transaction" do
        let(:transaction) { double }
        it "should call set_tags on transaction" do
          expect(transaction).to receive(:set_tags).with("a" => "b")
        end

        after { Appsignal.tag_request("a" => "b") }
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

    describe "custom stats" do
      describe ".set_gauge" do
        it "should call set_gauge on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:set_gauge).with("key", 0.1)
          Appsignal.set_gauge("key", 0.1)
        end

        it "should call set_gauge on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:set_gauge).with("key", 1.0)
          Appsignal.set_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:set_gauge).with("key", 10).and_raise(RangeError)
          expect(Appsignal.logger).to receive(:warn).with("Gauge value 10 for key 'key' is too big")
          expect do
            Appsignal.set_gauge("key", 10)
          end.to_not raise_error
        end
      end

      describe ".set_host_gauge" do
        it "should call set_host_gauge on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:set_host_gauge).with("key", 0.1)
          Appsignal.set_host_gauge("key", 0.1)
        end

        it "should call set_host_gauge on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:set_host_gauge).with("key", 1.0)
          Appsignal.set_host_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:set_host_gauge).with("key", 10).and_raise(RangeError)
          expect(Appsignal.logger).to receive(:warn).with("Host gauge value 10 for key 'key' is too big")
          expect do
            Appsignal.set_host_gauge("key", 10)
          end.to_not raise_error
        end
      end

      describe ".set_process_gauge" do
        it "should call set_process_gauge on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:set_process_gauge).with("key", 0.1)
          Appsignal.set_process_gauge("key", 0.1)
        end

        it "should call set_process_gauge on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:set_process_gauge).with("key", 1.0)
          Appsignal.set_process_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:set_process_gauge).with("key", 10).and_raise(RangeError)
          expect(Appsignal.logger).to receive(:warn).with("Process gauge value 10 for key 'key' is too big")
          expect do
            Appsignal.set_process_gauge("key", 10)
          end.to_not raise_error
        end
      end

      describe ".increment_counter" do
        it "should call increment_counter on the extension with a string key" do
          expect(Appsignal::Extension).to receive(:increment_counter).with("key", 1)
          Appsignal.increment_counter("key")
        end

        it "should call increment_counter on the extension with a symbol key" do
          expect(Appsignal::Extension).to receive(:increment_counter).with("key", 1)
          Appsignal.increment_counter(:key)
        end

        it "should call increment_counter on the extension with a count" do
          expect(Appsignal::Extension).to receive(:increment_counter).with("key", 5)
          Appsignal.increment_counter("key", 5)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:increment_counter).with("key", 10).and_raise(RangeError)
          expect(Appsignal.logger).to receive(:warn).with("Counter value 10 for key 'key' is too big")
          expect do
            Appsignal.increment_counter("key", 10)
          end.to_not raise_error
        end
      end

      describe ".add_distribution_value" do
        it "should call add_distribution_value on the extension with a string key and float" do
          expect(Appsignal::Extension).to receive(:add_distribution_value).with("key", 0.1)
          Appsignal.add_distribution_value("key", 0.1)
        end

        it "should call add_distribution_value on the extension with a symbol key and int" do
          expect(Appsignal::Extension).to receive(:add_distribution_value).with("key", 1.0)
          Appsignal.add_distribution_value(:key, 1)
        end

        it "should not raise an exception when out of range" do
          expect(Appsignal::Extension).to receive(:add_distribution_value).with("key", 10).and_raise(RangeError)
          expect(Appsignal.logger).to receive(:warn).with("Distribution value 10 for key 'key' is too big")
          expect do
            Appsignal.add_distribution_value("key", 10)
          end.to_not raise_error
        end
      end
    end

    describe ".logger" do
      subject { Appsignal.logger }

      it { is_expected.to be_a Logger }
    end

    describe ".start_logger" do
      let(:out_stream) { std_stream }
      let(:output) { out_stream.read }
      let(:log_path) { File.join(tmp_dir, "log") }
      let(:log_file) { File.join(log_path, "appsignal.log") }

      before do
        FileUtils.mkdir_p(log_path)

        Appsignal.logger.error("Log in memory")
        Appsignal.config = project_fixture_config(
          "production",
          :log_path => log_path
        )
      end
      after { FileUtils.rm_rf(log_path) }

      context "when the log path is writable" do
        context "when the log file is writable" do
          let(:log_file_contents) { File.open(log_file).read }

          before do
            capture_stdout(out_stream) do
              Appsignal.start_logger
              Appsignal.logger.error("Log to file")
            end
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
              Appsignal.start_logger
              Appsignal.logger.error("Log to not writable log file")
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
            expect(output).to include \
              "[WARN] appsignal: Unable to start logger with log path '#{log_file}'.",
              "[WARN] appsignal: Permission denied"
          end
        end
      end

      context "when the log path and fallback path are not writable" do
        before do
          FileUtils.chmod 0o444, log_path
          FileUtils.chmod 0o444, Appsignal::Config::SYSTEM_TMP_DIR

          capture_stdout(out_stream) do
            Appsignal.start_logger
            Appsignal.logger.error("Log to not writable log path")
          end
        end
        after do
          FileUtils.chmod 0o755, Appsignal::Config::SYSTEM_TMP_DIR
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
            "appsignal: Unable to log to '#{log_path}' "\
            "or the '#{Appsignal::Config::SYSTEM_TMP_DIR}' fallback."
        end
      end

      context "when on Heroku" do
        before do
          capture_stdout(out_stream) do
            Appsignal.start_logger
            Appsignal.logger.error("Log to stdout")
          end
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
        subject { Appsignal.logger.level }

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
              Appsignal.config.config_hash[:debug] = true
              capture_stdout(out_stream) do
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
      let(:tags) { nil }
      let(:error) { VerySpecificError.new }

      it "should send the error to AppSignal" do
        expect(Appsignal::Transaction).to receive(:new).and_call_original
      end

      context "with tags" do
        let(:tags) { { :a => "a", :b => "b" } }

        it "should tag the request before sending" do
          transaction = Appsignal::Transaction.new(
            SecureRandom.uuid,
            Appsignal::Transaction::HTTP_REQUEST,
            Appsignal::Transaction::GenericRequest.new({})
          )
          allow(Appsignal::Transaction).to receive(:new).and_return(transaction)
          expect(transaction).to receive(:set_tags).with(tags)
          expect(transaction).to receive(:complete)
        end
      end

      context "when given class is not an error" do
        let(:error) { double }

        it "should log a message" do
          expect(Appsignal.logger).to receive(:error).with('Can\'t send error, given value is not an exception')
        end

        it "should not send the error" do
          expect(Appsignal::Transaction).to_not receive(:create)
        end
      end

      after do
        Appsignal.send_error(error, tags)
      end
    end

    describe ".listen_for_error" do
      it "should call send_error and re-raise" do
        expect(Appsignal).to receive(:send_error).with(kind_of(Exception))
        expect do
          Appsignal.listen_for_error do
            raise "I am an exception"
          end
        end.to raise_error(RuntimeError, "I am an exception")
      end
    end

    describe ".set_error" do
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }
      let(:error) { RuntimeError.new("I am an exception") }

      it "should add the error to the current transaction" do
        expect(transaction).to receive(:set_error).with(error)

        Appsignal.set_error(error)
      end

      it "should do nothing if there is no current transaction" do
        allow(Appsignal::Transaction).to receive(:current).and_return(nil)

        expect(transaction).to_not receive(:set_error)

        Appsignal.set_error(error)
      end

      it "should do nothing if the error is nil" do
        expect(transaction).to_not receive(:set_error)

        Appsignal.set_error(nil)
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
      before do
        expect(Appsignal::Transaction).to receive(:current).at_least(:once).and_return(transaction)
      end

      it "should instrument through the transaction" do
        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event)
          .with("name", "title", "body", Appsignal::EventFormatter::DEFAULT)

        result = Appsignal.instrument "name", "title", "body" do
          "return value"
        end
        expect(result).to eq "return value"
      end

      it "should instrument without a block given" do
        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event)
          .with("name", "title", "body", Appsignal::EventFormatter::DEFAULT)

        result = Appsignal.instrument "name", "title", "body"
        expect(result).to be_nil
      end
    end

    describe ".instrument_sql" do
      before do
        expect(Appsignal::Transaction).to receive(:current).at_least(:once).and_return(transaction)
      end

      it "should instrument sql through the transaction" do
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
      let(:transaction) { double }
      before { allow(Appsignal::Transaction).to receive(:current).and_return(transaction) }

      it "should pause and unpause the transaction around the block" do
        expect(transaction).to receive(:pause!)
        expect(transaction).to receive(:resume!)
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "should not crash" do
          # just execute the after block
        end
      end

      after do
        Appsignal.without_instrumentation do
          # nothing
        end
      end
    end

    describe ".is_ignored_error?" do
      let(:error) { StandardError.new }
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      before do
        allow(Appsignal).to receive(:config).and_return(:ignore_errors => ["StandardError"])
      end

      subject do
        capture_std_streams(std_stream, err_stream) do
          Appsignal.is_ignored_error?(error)
        end
      end

      it "should return true if it's in the ignored list" do
        is_expected.to be_truthy
      end

      it "outputs deprecated warning" do
        subject
        expect(stderr).to include("Appsignal.is_ignored_error? is deprecated with no replacement.")
      end

      context "when error is not in the ignored list" do
        let(:error) { Object.new }

        it "should return false" do
          is_expected.to be_falsy
        end
      end
    end

    describe ".is_ignored_action?" do
      let(:action) { "TestController#isup" }
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      before do
        allow(Appsignal).to receive(:config).and_return(:ignore_actions => "TestController#isup")
      end

      subject do
        capture_std_streams(std_stream, err_stream) do
          Appsignal.is_ignored_action?(action)
        end
      end

      it "should return true if it's in the ignored list" do
        is_expected.to be_truthy
      end

      it "outputs deprecated warning" do
        subject
        expect(stderr).to include("Appsignal.is_ignored_action? is deprecated with no replacement.")
      end

      context "when action is not in the ingore list" do
        let(:action) { "TestController#other_action" }

        it "should return false" do
          is_expected.to be_falsy
        end
      end
    end
  end
end
