require 'spec_helper'

describe Appsignal do
  before do
    # Make sure we have a clean state because we want to test
    # initialization here.
    Appsignal.agent.shutdown if Appsignal.agent
    Appsignal.config = nil
    Appsignal.agent = nil
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

      it "should start an agent" do
        Appsignal.start
        Appsignal.agent.should be_a Appsignal::Agent
        Appsignal.logger.level.should == Logger::INFO
      end
    end

    context "with debug logging" do
      before { Appsignal.config = project_fixture_config('test') }

      it "should change the log level" do
        Appsignal.start
        Appsignal.logger.level.should == Logger::DEBUG
      end
    end
  end

  describe '.active?' do
    subject { Appsignal.active? }

    context "without config" do
      before { Appsignal.stub(:config => nil) }

      it { should be_false }
    end

    context "with config but inactive" do
      before { Appsignal.stub(:config => {:active => false}) }

      it { should be_false }
    end

    context "with active config" do
      before { Appsignal.stub(:config => {:active => true}) }

      it { should be_true }
    end
  end

  context "with config and started" do
    before do
      Appsignal.config = project_fixture_config
      Appsignal.start
    end

    describe ".enqueue" do
      subject { Appsignal.enqueue(transaction) }

      it "forwards the call to the agent" do
        Appsignal.agent.should respond_to(:enqueue)
        Appsignal.agent.should_receive(:enqueue).with(transaction)
        subject
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
    end

    describe ".transactions" do
      subject { Appsignal.transactions }

      it { should be_a Hash }
    end

    describe '.logger' do
      subject { Appsignal.logger }

      it { should be_a Logger }
    end

    describe '.config' do
      subject { Appsignal.config }

      it { should be_a Appsignal::Config }
      it 'should return configuration' do
        subject[:endpoint].should == 'https://push.appsignal.com/1'
      end
    end

    describe ".json" do
      subject { Appsignal.json }

      it { should == ActiveSupport::JSON }
    end

    describe ".post_processing_middleware" do
      before { Appsignal.instance_variable_set(:@post_processing_chain, nil) }

      it "returns the default middleware stack" do
        Appsignal::Aggregator::PostProcessor.should_receive(:default_middleware)
        Appsignal.post_processing_middleware
      end

      it "returns a chain when called without a block" do
        instance = Appsignal.post_processing_middleware
        instance.should be_an_instance_of Appsignal::Aggregator::Middleware::Chain
      end

      context "when passing a block" do
        it "yields an appsignal middleware chain" do
          Appsignal.post_processing_middleware do |o|
            o.should be_an_instance_of Appsignal::Aggregator::Middleware::Chain
          end
        end
      end
    end

    describe ".send_exception" do
      it "should send the exception to AppSignal" do
        agent = double
        Appsignal.stub(:agent).and_return(agent)
        agent.should_receive(:send_queue)
        agent.should_receive(:enqueue).with(kind_of(Appsignal::Transaction))

        Appsignal::Transaction.should_receive(:create).and_call_original
      end

      it "should not send the exception if it's in the ignored list" do
        Appsignal.stub(:is_ignored_exception? => true)
        Appsignal::Transaction.should_not_receive(:create)
      end

      after do
        begin
          raise "I am an exception"
        rescue Exception => e
          Appsignal.send_exception(e)
        end
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

    describe ".add_exception" do
      before { Appsignal::Transaction.stub(:current => transaction) }
      let(:exception) { RuntimeError.new('I am an exception') }

      it "should add the exception to the current transaction" do
        transaction.should_receive(:add_exception).with(exception)

        Appsignal.add_exception(exception)
      end

      it "should do nothing if there is no current transaction" do
        Appsignal::Transaction.stub(:current => nil)

        transaction.should_not_receive(:add_exception).with(exception)

        Appsignal.add_exception(exception)
      end

      it "should not add the exception if it's in the ignored list" do
        Appsignal.stub(:is_ignored_exception? => true)

        transaction.should_not_receive(:add_exception).with(exception)

        Appsignal.add_exception(exception)
      end

      it "should do nothing if the exception is nil" do
        transaction.should_not_receive(:add_exception)

        Appsignal.add_exception(nil)
      end
    end
  end
end
