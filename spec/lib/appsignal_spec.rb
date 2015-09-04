require 'spec_helper'
require './spec/support/mocks/mock_extension'

describe Appsignal do
  before do
    # Make sure we have a clean state because we want to test
    # initialization here.
    Appsignal.agent.shutdown if Appsignal.agent
    Appsignal.config = nil
    Appsignal.agent = nil
    Appsignal.extensions.clear
  end

  let(:transaction) { regular_transaction }

  describe ".config=" do
    it "should set the config" do
      config = project_fixture_config
      Appsignal.logger.should_not_receive(:level=)

      Appsignal.config = config
      Appsignal.config.should == config
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
    it "should do nothing when config is not loaded" do
      Appsignal.logger.should_receive(:error).with(
        "Can't start, no config loaded"
      )
      Appsignal.start
      Appsignal.agent.should be_nil
    end

    context "when config is loaded" do
      before { Appsignal.config = project_fixture_config }

      it "should initialize logging" do
        Appsignal.start
        Appsignal.logger.level.should == Logger::INFO
      end

      it "should start native" do
        Appsignal::Extension.should_receive(:start)
        Appsignal.start
      end

      it "should load integrations" do
        Appsignal.should_receive(:load_integrations)
        Appsignal.start
      end

      it "should load instrumentations" do
        Appsignal.should_receive(:load_instrumentations)
        Appsignal.start
      end

      it "should initialize formatters" do
        Appsignal::EventFormatter.should_receive(:initialize_formatters)
        Appsignal.start
      end

      it "should create a subscriber" do
        Appsignal.start
        Appsignal.subscriber.should be_a(Appsignal::Subscriber)
      end

      context "when not active for this environment" do
        before { Appsignal.config = project_fixture_config('staging') }

        it "should do nothing" do
          Appsignal.logger.should_receive(:info).with(
            'Not starting, not active for staging'
          )
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
    end

    describe ".load_integrations" do
      it "should require the integrations" do
        Appsignal.should_receive(:require).at_least(:once)
      end

      after { Appsignal.load_integrations }
    end

    describe ".load_instrumentations" do
      before { Appsignal.config = project_fixture_config }

      context "Net::HTTP" do
        context "if on in the config" do
          it "should require net_http" do
            Appsignal.should_receive(:require).with('appsignal/instrumentations/net_http')
          end
        end

        context "if off in the config" do
          before { Appsignal.config.config_hash[:instrument_net_http] = false }

          it "should not require net_http" do
            Appsignal.should_not_receive(:require).with('appsignal/instrumentations/net_http')
          end
        end
      end

      after { Appsignal.load_instrumentations }
    end

    context "with debug logging" do
      before { Appsignal.config = project_fixture_config('test') }

      it "should change the log level" do
        Appsignal.start
        Appsignal.logger.level.should == Logger::DEBUG
      end
    end
  end

  describe ".stop_agent" do
    it "should call stop_agent on the extension" do
      Appsignal::Extension.should_receive(:stop_agent)
      Appsignal.stop_agent
      Appsignal.active?.should be_false
    end
  end

  describe ".stop_extension" do
    it "should call stop_extension on the extension" do
      Appsignal::Extension.should_receive(:stop_extension)
      Appsignal.stop_extension
      Appsignal.active?.should be_false
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

  context "not active" do
    describe ".monitor_transaction" do
      it "should do nothing but still yield the block" do
        Appsignal::Transaction.should_not_receive(:create)
        ActiveSupport::Notifications.should_not_receive(:instrument)
        object = double
        object.should_receive(:some_method)

        lambda {
          Appsignal.monitor_transaction('perform_job.nothing') do
            object.some_method
          end
        }.should_not raise_error
      end
    end

    describe ".listen_for_exception" do
      it "should do nothing" do
        error = RuntimeError.new('specific error')
        lambda {
          Appsignal.listen_for_exception do
            raise error
          end
        }.should raise_error(error)
      end
    end

    describe ".send_exception" do
      it "should do nothing" do
        lambda {
          Appsignal.send_exception(RuntimeError.new)
        }.should_not raise_error
      end
    end

    describe ".set_exception" do
      it "should do nothing" do
        lambda {
          Appsignal.set_exception(RuntimeError.new)
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
  end

  context "with config and started" do
    before do
      Appsignal.config = project_fixture_config
      Appsignal.start
    end

    describe ".monitor_transaction" do
      context "with a normall call" do
        it "should instrument and complete" do
          Appsignal::Transaction.stub(:current => transaction)
          ActiveSupport::Notifications.should_receive(:instrument).with(
            'perform_job.something',
            :class => 'Something'
          ).and_yield
          Appsignal::Transaction.should_receive(:complete_current!)
          object = double
          object.should_receive(:some_method)

          Appsignal.monitor_transaction(
            'perform_job.something',
            :class => 'Something'
          ) do
            object.some_method
          end
        end
      end

      context "with an erroring call" do
        let(:error) { VerySpecificError.new('the roof') }

        it "should add the error to the current transaction and complete" do
          Appsignal.should_receive(:set_exception).with(error)
          Appsignal::Transaction.should_receive(:complete_current!)

          lambda {
            Appsignal.monitor_transaction('perform_job.something') do
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
        it "should call set_gauge on the extension" do
          Appsignal::Extension.should_receive(:set_gauge).with('key', 0.1)
          Appsignal.set_gauge('key', 0.1)
        end
      end

      describe ".set_host_gauge" do
        it "should call set_host_gauge on the extension" do
          Appsignal::Extension.should_receive(:set_host_gauge).with('key', 0.1)
          Appsignal.set_host_gauge('key', 0.1)
        end
      end

      describe ".set_process_gauge" do
        it "should call set_process_gauge on the extension" do
          Appsignal::Extension.should_receive(:set_process_gauge).with('key', 0.1)
          Appsignal.set_process_gauge('key', 0.1)
        end
      end

      describe ".increment_counter" do
        it "should call increment_counter on the extension" do
          Appsignal::Extension.should_receive(:increment_counter).with('key', 1)
          Appsignal.increment_counter('key', 1)
        end
      end

      describe ".add_distribution_value" do
        it "should call increment_counter on the extension" do
          Appsignal::Extension.should_receive(:add_distribution_value).with('key', 0.1)
          Appsignal.add_distribution_value('key', 0.1)
        end
      end
    end

    describe '.logger' do
      subject { Appsignal.logger }

      it { should be_a Logger }
    end

    describe ".start_logger" do
      let(:out_stream) { StringIO.new }
      let(:log_file) { File.join(path, 'appsignal.log') }
      before do
        @original_stdout = $stdout
        $stdout = out_stream
        Appsignal.logger.error('Log something')
      end
      after do
        $stdout = @original_stdout
      end

      context "when the log path is writable" do
        let(:path) { File.join(project_fixture_path, 'log') }
        before { Appsignal.start_logger(path) }

        it "should log to file" do
          File.exists?(log_file).should be_true
          File.open(log_file).read.should include 'Log something'
        end
      end

      context "when the log path is not writable" do
        let(:path) { '/nonsense/log' }
        before { Appsignal.start_logger(path) }

        it "should log to stdout" do
          Appsignal.logger.error('Log to stdout')
          out_stream.string.should include 'appsignal: Log to stdout'
        end
      end

      context "when we're on Heroku" do
        let(:path) { File.join(project_fixture_path, 'log') }
        before do
          ENV['DYNO'] = 'dyno1'
          Appsignal.start_logger(path)
        end
        after { ENV.delete('DYNO') }

        it "should log to stdout" do
          Appsignal.logger.error('Log to stdout')
          out_stream.string.should include 'appsignal: Log to stdout'
        end
      end

      context "when we're on Shelly Cloud" do
        let(:path) { File.join(project_fixture_path, 'log') }
        before do
          ENV['SHELLYCLOUD_DEPLOYMENT'] = 'true'
          Appsignal.start_logger(path)
        end
        after { ENV.delete('SHELLYCLOUD_DEPLOYMENT') }

        it "should log to stdout" do
          Appsignal.logger.error('Log to stdout')
          out_stream.string.should include 'appsignal: Log to stdout'
        end
      end

      context "when there is no in memory log" do
        it "should not crash" do
          Appsignal.in_memory_log = nil
          Appsignal.start_logger(nil)
        end
      end
    end

    describe ".log_formatter" do
      subject { Appsignal.log_formatter }

      it "should format a log line" do
        Process.stub(:pid => 100)
        subject.call('Debug', Time.parse('2015-07-08'), nil, 'log line').should ==
          "[2015-07-08T00:00:00 (process) #100][Debug] log line\n"
      end
    end

    describe '.config' do
      subject { Appsignal.config }

      it { should be_a Appsignal::Config }
      it 'should return configuration' do
        subject[:endpoint].should == 'https://push.appsignal.com'
      end
    end

    describe ".send_exception" do
      let(:tags)      { nil }
      let(:exception) { VerySpecificError.new }

      it "should send the exception to AppSignal" do
        Appsignal::Transaction.should_receive(:create).and_call_original
      end

      context "with tags" do
        let(:tags) { {:a => 'a', :b => 'b'} }

        it "should tag the request before sending" do
          transaction = Appsignal::Transaction.create(SecureRandom.uuid, {})
          Appsignal::Transaction.stub(:create => transaction)
          transaction.should_receive(:set_tags).with(tags)
          Appsignal::Transaction.should_receive(:complete_current!)
        end
      end

      it "should not send the exception if it's in the ignored list" do
        Appsignal.stub(:is_ignored_exception? => true)
        Appsignal::Transaction.should_not_receive(:create)
      end

      context "when given class is not an exception" do
        let(:exception) { double }

        it "should log a message" do
          expect( Appsignal.logger ).to receive(:error).with('Can\'t send exception, given value is not an exception')
        end

        it "should not send the exception" do
          expect( Appsignal::Transaction ).to_not receive(:create)
        end
      end

      after do
        Appsignal.send_exception(exception, tags) rescue Exception
      end
    end

    describe ".listen_for_exception" do
      it "should call send_exception and re-raise" do
        Appsignal.should_receive(:send_exception).with(kind_of(Exception))
        lambda {
          Appsignal.listen_for_exception do
            raise "I am an exception"
          end
        }.should raise_error(RuntimeError, "I am an exception")
      end
    end

    describe ".set_exception" do
      before { Appsignal::Transaction.stub(:current => transaction) }
      let(:exception) { RuntimeError.new('I am an exception') }

      it "should add the exception to the current transaction" do
        transaction.should_receive(:set_error).with(exception)

        Appsignal.set_exception(exception)
      end

      it "should do nothing if there is no current transaction" do
        Appsignal::Transaction.stub(:current => nil)

        transaction.should_not_receive(:set_exception).with(exception)

        Appsignal.set_exception(exception)
      end

      it "should not add the exception if it's in the ignored list" do
        Appsignal.stub(:is_ignored_exception? => true)

        transaction.should_not_receive(:set_exception).with(exception)

        Appsignal.set_exception(exception)
      end

      it "should do nothing if the exception is nil" do
        transaction.should_not_receive(:set_exception)

        Appsignal.set_exception(nil)
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

    describe ".is_ignored_exception?" do
      let(:exception) { StandardError.new }
      before do
        Appsignal.stub(
          :config => {:ignore_exceptions => 'StandardError'}
        )
      end

      subject { Appsignal.is_ignored_exception?(exception) }

      it "should return true if it's in the ignored list" do
        should be_true
      end

      context "when exception is not in the ingore list" do
        let(:exception) { Object.new }

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
