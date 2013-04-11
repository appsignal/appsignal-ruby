require 'spec_helper'

describe Appsignal::AuthCheck do
  let(:auth_check) { Appsignal::AuthCheck.new('production') }
  before do
    @transmitter = mock
    Appsignal::Transmitter.should_receive(:new).
      with('http://localhost:3000/1', 'auth', 'def').
      and_return(@transmitter)
  end

  describe "#perform" do
    it "should not transmit any extra data" do
      @transmitter.should_receive(:transmit).with({}).and_return({})
      auth_check.perform
    end
  end

  describe "#uri" do
    before do
      @transmitter.should_receive(:transmit)
      auth_check.perform
    end

    it "should delegate to transmitter" do
      @transmitter.should_receive(:uri)
      auth_check.uri
    end

    it "should return uri" do
      @transmitter.should_receive(:uri).
        and_return('http://appsignal.com/1/auth')
      auth_check.uri.should == 'http://appsignal.com/1/auth'
    end
  end
end
