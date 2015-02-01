require 'spec_helper'

describe Appsignal::AuthCheck do
  let(:config) { project_fixture_config }
  let(:logger) { Logger.new(StringIO.new) }
  let(:auth_check) { Appsignal::AuthCheck.new(config, logger) }

  describe "#perform" do
    it "should call the native agent" do
      Appsignal::Native.should_receive(:check_push_api_auth).and_return(200)
      auth_check.perform
    end
  end

  describe "#perform_with_result" do
    it "should give a success message" do
      auth_check.should_receive(:perform).and_return(200)
      auth_check.perform_with_result.should ==
        [200, 'AppSignal has confirmed authorization!']
    end

    it "should give a 401 message" do
      auth_check.should_receive(:perform).and_return(401)
      auth_check.perform_with_result.should ==
        [401, 'API key not valid with AppSignal...']
    end

    it "should give an error message" do
      auth_check.should_receive(:perform).and_return(402)
      auth_check.perform_with_result.should ==
        [402, 'Could not confirm authorization: 402']
    end
  end
end
