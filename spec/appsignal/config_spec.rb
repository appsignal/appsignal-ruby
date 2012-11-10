require 'spec_helper'

describe Appsignal::Config do
  subject { Appsignal::Config.new(Dir.pwd, 'test').load }

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

    after { subject }
  end

  context "the env is not in the config" do
    subject { Appsignal::Config.new(Dir.pwd, 'staging').load }

    it "should generate error" do
      Appsignal.logger.should_receive(:error).with(
        "config for 'staging' not found"
      )
    end

    after { subject }
  end
end
