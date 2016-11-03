require './spec/support/mocks/mock_extension'

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
      Appsignal.logger.should_not_receive(:level=)

      Appsignal.config = config
      Appsignal.config.should eq config
    end
  end

  describe ".extensions" do
    it "should keep a list of extensions" do
      Appsignal.extensions.should be_empty
      Appsignal.extensions << Appsignal::MockExtension
      Appsignal.extensions.should have(1).item
    end
  end

  describe ".start" do
    context "with no config set beforehand" do
      it "should do nothing when config is not set and there is no valid config in the env" do
        Appsignal.logger.should_receive(:error).with(
          "Push api key not set after loading config"
        ).once
        Appsignal.logger.should_receive(:error).with(
          "Not starting, no valid config for this environment"
        ).once
        Appsignal::Extension.should_not_receive(:start)
        Appsignal.start
      end

      it "should create a config from the env" do
        ENV['APPSIGNAL_PUSH_API_KEY'] = 'something'
        Appsignal::Extension.should_receive(:start)
        Appsignal.start
      end
    end

    context "when config is loaded" do
      before { Appsignal.config = project_fixture_config }

      it "should initialize logging" do
        Appsignal.start
        Appsignal.logger.level.should eq Logger::INFO
      end

      it "should start native" do
        Appsignal::Extension.should_receive(:start)
        Appsignal.start
      end

      it "should initialize formatters" do
        Appsignal::EventFormatter.should_receive(:initialize_formatters)
        Appsignal.start
      end

      context "when not active for this environment" do
        before { Appsignal.config = project_fixture_config('staging') }

        it "should do nothing" do
          Appsignal.start
          Appsignal.agent.should be_nil
        end
      end

      context "with an extension" do
        before { Appsignal.extensions << Appsignal::MockExtension }

        it "should call the extension's initializer" do
          Appsignal::MockExtension.should_receive(:initializer)
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
          Appsignal::Minutely.should_receive(:start)
          Appsignal.start
        end
      end

      context "when minutely metrics has been disabled" do
        before do
          Appsignal.config.config_hash[:enable_minutely_probes] = false
        end

        it "should not start minutely" do
          Appsignal::Minutely.should_not_receive(:start)
          Appsignal.start
        end
      end
    end

    context "with debug logging" do
      before { Appsignal.config = project_fixture_config('test') }

      it "should change the log level" do
        Appsignal.start
        Appsignal.logger.level.should eq Logger::DEBUG
      end
    end
  end

  describe ".forked" do
    context "when not active" do
      it "should should do nothing" do
        Appsignal::Extension.should_not_receive(:start)

        Appsignal.forked
      end
    end

    context "when active" do
      before do
        Appsignal.config = project_fixture_config
      end

      it "should resubscribe and start the extension" do
        Appsignal.should_receive(:start_logger)
        Appsignal::Extension.should_receive(:start)

        Appsignal.forked
      end
    end
  end

  describe ".stop" do
    it "should call stop on the extension" do
      Appsignal.logger.should_receive(:debug).with('Stopping appsignal')
      Appsignal::Extension.should_receive(:stop)
      Appsignal.stop
      Appsignal.active?.should be_false
    end

    context "with context specified" do
      it "should log the context" do
        Appsignal.logger.should_receive(:debug).with('Stopping appsignal (something)')
        Appsignal::Extension.should_receive(:stop)
        Appsignal.stop('something')
        Appsignal.active?.should be_false
      end
    end
  end

  describe '.active?' do
    subject { Appsignal.active? }

    context "without config" do
      before do
        Appsignal.config = nil
      end

      it { should be_false }
    end

    context "with inactive config" do
      before do
        Appsignal.config = project_fixture_config('nonsense')
      end

      it { should be_false }
    end

    context "with active config" do
      before do
        Appsignal.config = project_fixture_config
      end

      it { should be_true }
    end
  end

  describe ".add_exception" do
    it "should alias this method" do
      Appsignal.should respond_to(:add_exception)
    end
  end

  describe ".get_server_state" do
    it "should call server state on the extension" do
      Appsignal::Extension.should_receive(:get_server_state).with('key')

      Appsignal.get_server_state('key')
    end

    it "should get nil by default" do
      Appsignal.get_server_state('key').should be_nil
    end
  end

  context "not active" do
    describe ".monitor_transaction" do
      it "should do nothing but still yield the block" do
        Appsignal::Transaction.should_not_receive(:create)
        Appsignal.should_not_receive(:instrument)
        object = double
        object.should_receive(:some_method).and_return(1)

        lambda {
          Appsignal.monitor_transaction('perform_job.nothing') do
            object.some_method
          end.should eq 1
        }.should_not raise_error
      end
    end

    describe ".listen_for_error" do
      it "should do nothing" do
        error = RuntimeError.new('specific error')
        lambda {
          Appsignal.listen_for_error do
            raise error
          end
        }.should raise_error(error)
      end
    end

    describe ".send_error" do
      it "should do nothing" do
        lambda {
          Appsignal.send_error(RuntimeError.new)
        }.should_not raise_error
      end
    end

    describe ".set_error" do
      it "should do nothing" do
        lambda {
          Appsignal.set_error(RuntimeError.new)
        }.should_not raise_error
      end
    end

    describe ".tag_request" do
      it "should do nothing" do
        lambda {
          Appsignal.tag_request(:tag => 'tag')
        }.should_not raise_error
      end
    end

    describe ".instrument" do
      it "should not instrument, but still call the block" do
        stub = double
        stub.should_receive(:method_call).and_return('return value')

        lambda {
          Appsignal.instrument 'name' do
            stub.method_call
          end.should eq 'return value'
        }.should_not raise_error
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
          Appsignal.should_receive(:instrument).with(
            'perform_job.something'
          ).and_yield
          Appsignal::Transaction.should_receive(:complete_current!)
          object = double
          object.should_receive(:some_method).and_return(1)

          Appsignal.monitor_transaction(
            'perform_job.something',
            background_env_with_data
          ) do
            current = Appsignal::Transaction.current
            current.namespace.should eq Appsignal::Transaction::BACKGROUND_JOB
            current.request.should be_a(Appsignal::Transaction::GenericRequest)
            object.some_method
          end.should eq 1
        end

        it "should instrument and complete for a http request" do
          Appsignal.should_receive(:instrument).with(
            'process_action.something'
          ).and_yield
          Appsignal::Transaction.should_receive(:complete_current!)
          object = double
          object.should_receive(:some_method)

          Appsignal.monitor_transaction(
            'process_action.something',
            http_request_env_with_data
          ) do
            current = Appsignal::Transaction.current
            current.namespace.should eq Appsignal::Transaction::HTTP_REQUEST
            current.request.should be_a(::Rack::Request)
            object.some_method
          end
        end
      end

      context "with an erroring call" do
        let(:error) { VerySpecificError.new }

        it "should add the error to the current transaction and complete" do
          Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
          Appsignal::Transaction.should_receive(:complete_current!)

          lambda {
            Appsignal.monitor_transaction('perform_job.something') do
              raise error
            end
          }.should raise_error(error)
        end
      end
    end

    describe ".monitor_single_transaction" do
      context "with a successful call" do
        it "should call monitor_transaction and stop" do
          Appsignal.should_receive(:monitor_transaction).with(
            'perform_job.something',
            :key => :value
          ).and_yield
          Appsignal.should_receive(:stop)

          Appsignal.monitor_single_transaction('perform_job.something', :key => :value) do
            # nothing
          end
        end
      end

      context "with an erroring call" do
        let(:error) { VerySpecificError.new }

        it "should call monitor_transaction and stop and then raise the error" do
          Appsignal.should_receive(:monitor_transaction).with(
            'perform_job.something',
            :key => :value
          ).and_yield
          Appsignal.should_receive(:stop)

          lambda {
            Appsignal.monitor_single_transaction('perform_job.something', :key => :value) do
              raise error
            end
          }.should raise_error(error)
        end
      end
    end

    describe ".tag_request" do
      before { Appsignal::Transaction.stub(:current => transaction) }

      context "with transaction" do
        let(:transaction) { double }
        it "should call set_tags on transaction" do

          transaction.should_receive(:set_tags).with({'a' => 'b'})
        end

        after { Appsignal.tag_request({'a' => 'b'}) }
      end

      context "without transaction" do
        let(:transaction) { nil }

        it "should call set_tags on transaction" do
          Appsignal.tag_request.should be_false
        end
      end

      it "should also listen to tag_job" do
        Appsignal.should respond_to(:tag_job)
      end
    end

    describe "custom stats" do
      describe ".set_gauge" do
        it "should call set_gauge on the extension with a string key and float" do
          Appsignal::Extension.should_receive(:set_gauge).with('key', 0.1)
          Appsignal.set_gauge('key', 0.1)
        end

        it "should call set_gauge on the extension with a symbol key and int" do
          Appsignal::Extension.should_receive(:set_gauge).with('key', 1.0)
          Appsignal.set_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          Appsignal::Extension.should_receive(:set_gauge).with('key', 10).and_raise(RangeError)
          Appsignal.logger.should_receive(:warn).with("Gauge value 10 for key 'key' is too big")
          lambda {
            Appsignal.set_gauge('key', 10)
          }.should_not raise_error
        end
      end

      describe ".set_host_gauge" do
        it "should call set_host_gauge on the extension with a string key and float" do
          Appsignal::Extension.should_receive(:set_host_gauge).with('key', 0.1)
          Appsignal.set_host_gauge('key', 0.1)
        end

        it "should call set_host_gauge on the extension with a symbol key and int" do
          Appsignal::Extension.should_receive(:set_host_gauge).with('key', 1.0)
          Appsignal.set_host_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          Appsignal::Extension.should_receive(:set_host_gauge).with('key', 10).and_raise(RangeError)
          Appsignal.logger.should_receive(:warn).with("Host gauge value 10 for key 'key' is too big")
          lambda {
            Appsignal.set_host_gauge('key', 10)
          }.should_not raise_error
        end
      end

      describe ".set_process_gauge" do
        it "should call set_process_gauge on the extension with a string key and float" do
          Appsignal::Extension.should_receive(:set_process_gauge).with('key', 0.1)
          Appsignal.set_process_gauge('key', 0.1)
        end

        it "should call set_process_gauge on the extension with a symbol key and int" do
          Appsignal::Extension.should_receive(:set_process_gauge).with('key', 1.0)
          Appsignal.set_process_gauge(:key, 1)
        end

        it "should not raise an exception when out of range" do
          Appsignal::Extension.should_receive(:set_process_gauge).with('key', 10).and_raise(RangeError)
          Appsignal.logger.should_receive(:warn).with("Process gauge value 10 for key 'key' is too big")
          lambda {
            Appsignal.set_process_gauge('key', 10)
          }.should_not raise_error
        end
      end

      describe ".increment_counter" do
        it "should call increment_counter on the extension with a string key" do
          Appsignal::Extension.should_receive(:increment_counter).with('key', 1)
          Appsignal.increment_counter('key')
        end

        it "should call increment_counter on the extension with a symbol key" do
          Appsignal::Extension.should_receive(:increment_counter).with('key', 1)
          Appsignal.increment_counter(:key)
        end

        it "should call increment_counter on the extension with a count" do
          Appsignal::Extension.should_receive(:increment_counter).with('key', 5)
          Appsignal.increment_counter('key', 5)
        end

        it "should not raise an exception when out of range" do
          Appsignal::Extension.should_receive(:increment_counter).with('key', 10).and_raise(RangeError)
          Appsignal.logger.should_receive(:warn).with("Counter value 10 for key 'key' is too big")
          lambda {
            Appsignal.increment_counter('key', 10)
          }.should_not raise_error
        end
      end

      describe ".add_distribution_value" do
        it "should call add_distribution_value on the extension with a string key and float" do
          Appsignal::Extension.should_receive(:add_distribution_value).with('key', 0.1)
          Appsignal.add_distribution_value('key', 0.1)
        end

        it "should call add_distribution_value on the extension with a symbol key and int" do
          Appsignal::Extension.should_receive(:add_distribution_value).with('key', 1.0)
          Appsignal.add_distribution_value(:key, 1)
        end

        it "should not raise an exception when out of range" do
          Appsignal::Extension.should_receive(:add_distribution_value).with('key', 10).and_raise(RangeError)
          Appsignal.logger.should_receive(:warn).with("Distribution value 10 for key 'key' is too big")
          lambda {
            Appsignal.add_distribution_value('key', 10)
          }.should_not raise_error
        end
      end
    end

    describe '.logger' do
      subject { Appsignal.logger }

      it { should be_a Logger }
    end

    describe ".start_logger" do
      let(:out_stream) { StringIO.new }
      let(:log_path) { File.join(tmp_dir, 'log') }
      let(:log_file) { File.join(log_path, 'appsignal.log') }

      before do
        FileUtils.mkdir_p(log_path)

        Appsignal.logger.error('Log in memory')
        Appsignal.config = project_fixture_config(
          'production',
          :log_path => log_path
        )
      end
      around do |example|
        recognize_as_container(:none) do
          capture_stdout(out_stream) { example.run }
        end
      end
      after { FileUtils.rm_rf(log_path) }

      context "when the log path is writable" do
        context "when the log file is writable" do
          let(:log_file_contents) { File.open(log_file).read }
          before do
            Appsignal.start_logger
            Appsignal.logger.error('Log to file')
          end

          it "logs to file" do
            expect(File.exist?(log_file)).to be_true
            expect(log_file_contents).to include '[ERROR] Log to file'
          end

          it "amends in memory log to log file" do
            expect(log_file_contents).to include '[ERROR] appsignal: Log in memory'
          end
        end

        context "when the log file is not writable" do
          before do
            FileUtils.touch log_file
            FileUtils.chmod 0444, log_file

            Appsignal.start_logger
            Appsignal.logger.error('Log to not writable log file')
          end

          it "logs to stdout" do
            expect(File.writable?(log_file)).to be_false
            expect(out_stream.string).to include '[ERROR] appsignal: Log to not writable log file'
          end

          it "amends in memory log to stdout" do
            expect(out_stream.string).to include '[ERROR] appsignal: Log in memory'
          end

          it "outputs a warning" do
            expect(out_stream.string).to include \
              "[WARN] appsignal: Unable to start logger with log path '#{log_file}'.",
              "[WARN] appsignal: Permission denied"
          end
        end
      end

      context "when the log path is not writable" do
        before do
          FileUtils.chmod 0444, log_path

          Appsignal.start_logger
          Appsignal.logger.error('Log to not writable log path')
        end

        it "logs to stdout" do
          expect(File.writable?(log_path)).to be_false
          expect(out_stream.string).to include '[ERROR] appsignal: Log to not writable log path'
        end

        it "amends in memory log to stdout" do
          expect(out_stream.string).to include '[ERROR] appsignal: Log in memory'
        end

        it "outputs a warning" do
          expect(out_stream.string).to include \
            "appsignal: Unable to log to '#{log_path}' "\
            "or the '#{Appsignal::Config::SYSTEM_TMP_DIR}' fallback."
        end
      end

      context "when on Heroku" do
        before do
          Appsignal.start_logger
          Appsignal.logger.error('Log to stdout')
        end
        around { |example| recognize_as_heroku { example.run } }

        it "logs to stdout" do
          expect(out_stream.string).to include '[ERROR] appsignal: Log to stdout'
        end

        it "amends in memory log to stdout" do
          expect(out_stream.string).to include '[ERROR] appsignal: Log in memory'
        end
      end

      describe "#logger#level" do
        subject { Appsignal.logger.level }

        context "when there is no config" do
          before do
            Appsignal.config = nil
            Appsignal.start_logger
          end

          it "sets the log level to info" do
            expect(subject).to eq Logger::INFO
          end
        end

        context "when there is a config" do
          context "when log level is configured to debug" do
            before do
              Appsignal.config.config_hash[:debug] = true
              Appsignal.start_logger
            end

            it "sets the log level to debug" do
              expect(subject).to eq Logger::DEBUG
            end
          end
        end
      end
    end

    describe ".log_formatter" do
      subject { Appsignal.log_formatter.call('Debug', Time.parse('2015-07-08'), nil, 'log line') }

      it "formats a log" do
        expect(subject).to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] log line\n"
      end

      context "with prefix" do
        subject do
          Appsignal.log_formatter("prefix").call('Debug', Time.parse('2015-07-08'), nil, 'log line')
        end

        it "adds a prefix" do
          expect(subject)
            .to eq "[2015-07-08T00:00:00 (process) ##{Process.pid}][Debug] prefix: log line\n"
        end
      end
    end

    describe '.config' do
      subject { Appsignal.config }

      it { should be_a Appsignal::Config }
      it 'should return configuration' do
        subject[:endpoint].should eq 'https://push.appsignal.com'
      end
    end

    describe ".send_error" do
      let(:tags)      { nil }
      let(:error) { VerySpecificError.new }

      it "should send the error to AppSignal" do
        Appsignal::Transaction.should_receive(:new).and_call_original
      end

      context "with tags" do
        let(:tags) { {:a => 'a', :b => 'b'} }

        it "should tag the request before sending" do
          transaction = Appsignal::Transaction.new(
            SecureRandom.uuid,
            Appsignal::Transaction::HTTP_REQUEST,
            Appsignal::Transaction::GenericRequest.new({})
          )
          Appsignal::Transaction.stub(:new => transaction)
          transaction.should_receive(:set_tags).with(tags)
          transaction.should_receive(:complete)
        end
      end

      it "should not send the error if it's in the ignored list" do
        Appsignal.stub(:is_ignored_error? => true)
        Appsignal::Transaction.should_not_receive(:create)
      end

      context "when given class is not an error" do
        let(:error) { double }

        it "should log a message" do
          expect( Appsignal.logger ).to receive(:error).with('Can\'t send error, given value is not an exception')
        end

        it "should not send the error" do
          expect( Appsignal::Transaction ).to_not receive(:create)
        end
      end

      after do
        Appsignal.send_error(error, tags)
      end
    end

    describe ".listen_for_error" do
      it "should call send_error and re-raise" do
        Appsignal.should_receive(:send_error).with(kind_of(Exception))
        lambda {
          Appsignal.listen_for_error do
            raise "I am an exception"
          end
        }.should raise_error(RuntimeError, "I am an exception")
      end
    end

    describe ".set_error" do
      before { Appsignal::Transaction.stub(:current => transaction) }
      let(:error) { RuntimeError.new('I am an exception') }

      it "should add the error to the current transaction" do
        transaction.should_receive(:set_error).with(error)

        Appsignal.set_error(error)
      end

      it "should do nothing if there is no current transaction" do
        Appsignal::Transaction.stub(:current => nil)

        transaction.should_not_receive(:set_error)

        Appsignal.set_error(error)
      end

      it "should not add the error if it's in the ignored list" do
        Appsignal.stub(:is_ignored_error? => true)

        transaction.should_not_receive(:set_error)

        Appsignal.set_error(error)
      end

      it "should do nothing if the error is nil" do
        transaction.should_not_receive(:set_error)

        Appsignal.set_error(nil)
      end
    end

    describe ".instrument" do
      before do
        expect(Appsignal::Transaction).to receive(:current).at_least(:once).and_return(transaction)
      end

      it "should instrument through the transaction" do
        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event)
          .with('name', 'title', 'body', Appsignal::EventFormatter::DEFAULT)

        result = Appsignal.instrument 'name', 'title', 'body' do
          'return value'
        end
        expect(result).to eq 'return value'
      end
    end

    describe ".instrument_sql" do
      before do
        expect(Appsignal::Transaction).to receive(:current).at_least(:once).and_return(transaction)
      end

      it "should instrument sql through the transaction" do
        expect(transaction).to receive(:start_event)
        expect(transaction).to receive(:finish_event)
          .with('name', 'title', 'body', Appsignal::EventFormatter::SQL_BODY_FORMAT)

        result = Appsignal.instrument_sql 'name', 'title', 'body' do
          'return value'
        end
        expect(result).to eq 'return value'
      end
    end

    describe ".without_instrumentation" do
      let(:transaction) { double }
      before { Appsignal::Transaction.stub(:current => transaction) }

      it "should pause and unpause the transaction around the block" do
        transaction.should_receive(:pause!)
        transaction.should_receive(:resume!)
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
      before do
        Appsignal.stub(
          :config => {:ignore_errors => ['StandardError']}
        )
      end

      subject { Appsignal.is_ignored_error?(error) }

      it "should return true if it's in the ignored list" do
        should be_true
      end

      context "when error is not in the ignored list" do
        let(:error) { Object.new }

        it "should return false" do
          should be_false
        end
      end
    end

    describe ".is_ignored_action?" do
      let(:action) { 'TestController#isup' }
      before do
        Appsignal.stub(
          :config => {:ignore_actions => 'TestController#isup'}
        )
      end

      subject { Appsignal.is_ignored_action?(action) }

      it "should return true if it's in the ignored list" do
        should be_true
      end

      context "when action is not in the ingore list" do
        let(:action) { 'TestController#other_action' }

        it "should return false" do
          should be_false
        end
      end
    end
  end
end
