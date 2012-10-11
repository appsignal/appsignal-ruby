require 'spec_helper'

describe Appsignal::Config do
  subject { Appsignal::Config.new(Dir.pwd, 'test').load }

  it {
    should == {
      :ignore_exceptions => [],
      :endpoint => 'http://localhost:3000/api/1',
      :slow_request_threshold => 200,
      :api_key => 'abc',
      :active => true
    }
  }

  context 'when there is no config file' do
    before{ Dir.stub(:pwd => '/not/existing') }

    it "should generate error" do
      lambda {
        subject
      }.should raise_error(
        "config not found at:"\
        " /not/existing/config/appsignal.yml"
      )
    end
  end

  context "the env is not in the config" do
    subject { Appsignal::Config.new(Dir.pwd, 'staging').load }

    it "should generate error" do
      lambda {
        subject
      }.should raise_error(
        "config for 'staging' environment not found"
      )
    end
  end
end
