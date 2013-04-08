require 'spec_helper'

describe Appsignal::Config do
  let(:logger_parameter) { [] }
  subject { Appsignal::Config.new(Dir.pwd, 'test', *logger_parameter).load }

  it {
    should == {
      :ignore_exceptions => [],
      :endpoint => 'http://localhost:3000/1',
      :slow_request_threshold => 200,
      :api_key => 'abc',
      :active => true
    }
  }

  context 'when there is no config file' do
    before { Dir.stub(:pwd => '/not/existing') }

    it "should log error" do
      Appsignal.logger.should_receive(:error).with(
        "config not found at:"\
        " /not/existing/config/appsignal.yml"
      )
    end

    context "when the logger has no #error method" do
      let(:logger) { mock(:logger) }
      let(:logger_parameter) { [logger] }

      it "should log the error using #important" do
        logger.should_receive(:important).with(
          "config not found at:"\
          " /not/existing/config/appsignal.yml"
        )
      end
    end

    after { subject }
  end

  context "the env is not in the config" do
    subject { Appsignal::Config.new(Dir.pwd, 'staging', *logger_parameter).load }

    it "should generate error" do
      Appsignal.logger.should_receive(:error).with(
        "config for 'staging' not found"
      )
    end

    context "when the logger has no #error method" do
      let(:logger) { mock(:logger) }
      let(:logger_parameter) { [logger] }

      it "should log the error using #important" do
        logger.should_receive(:important).with(
          "config for 'staging' not found"
        )
      end
    end

    after { subject }
  end
end
