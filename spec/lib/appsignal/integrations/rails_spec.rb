require 'spec_helper'

if rails_present?
  describe Appsignal::Integrations::Railtie do
    context "after initializing the app" do
      before :all do
        MyApp::Application.config.root = project_fixture_path
        MyApp::Application.initialize!
      end

      context "logger" do
        subject { Appsignal.logger }

        it { should be_a Logger }
      end

      context "config" do
        subject { Appsignal.config }

        it { should be_a(Appsignal::Config) }

        its(:root_path) { should == Pathname.new(project_fixture_path) }
        its(:env) { should == 'test' }
        its([:name]) { should == 'TestApp' }

        context "initial config" do
          subject { Appsignal.config.initial_config }

          its([:name]) { should == 'MyApp' }
        end
      end

      context "agent" do
        subject { Appsignal.agent }

        it { should be_a(Appsignal::Agent) }
      end

      it "should have added the listener middleware" do
        MyApp::Application.middleware.to_a.should include Appsignal::Rack::Listener
      end

      it "should have added the js exception catcher middleware" do
        MyApp::Application.middleware.to_a.should include Appsignal::Rack::JSExceptionCatcher
      end

      it "should not have added the instrumentation middleware" do
        MyApp::Application.middleware.to_a.should_not include Appsignal::Rack::Instrumentation
      end
    end
  end
end
