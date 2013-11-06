require 'spec_helper'

begin
  require 'sinatra'
rescue LoadError
end

if defined?(::Sinatra)
  ENV['APPSIGNAL_PUSH_API_KEY'] = 'key'
  require 'appsignal/integrations/sinatra'

  describe "Sinatra integration" do
    context "logger" do
      subject { Appsignal.logger }

      it { should be_a Logger }
    end

    context "config" do
      subject { Appsignal.config }

      it { should be_a(Appsignal::Config) }
    end

    context "agent" do
      subject { Appsignal.agent }

      it { should be_a(Appsignal::Agent) }
    end

    it "should have added the listener middleware" do
      Sinatra::Application.middleware.to_a.should include(
        [Appsignal::Rack::Listener, [], nil]
      )
    end

    it "should have added the instrumentation middleware" do
      Sinatra::Application.middleware.to_a.should include(
        [Appsignal::Rack::Instrumentation, [], nil]
      )
    end
  end
end
