require 'spec_helper'

if rails_present?
  describe Appsignal::Integrations::Railtie do
    context "after initializing the app" do
      it "should call initialize_appsignal" do
        expect( Appsignal::Integrations::Railtie ).to receive(:initialize_appsignal)

        MyApp::Application.config.root = project_fixture_path
        MyApp::Application.initialize!
      end
    end

    describe "#initialize_appsignal" do
      let(:app) { MyApp::Application }
      before { app.middleware.stub(:insert_before => true) }

      context "logger" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.logger }

        it { should be_a Logger }
      end

      context "config" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.config }

        it { should be_a(Appsignal::Config) }

        its(:root_path) { should == Pathname.new(project_fixture_path) }
        its(:env)       { should == 'test' }
        its([:name])    { should == 'TestApp' }

        context "initial config" do
          before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
          subject { Appsignal.config.initial_config }

          its([:name]) { should == 'MyApp' }
        end

        context "with APPSIGNAL_APP_ENV ENV var set" do
          around do |sample|
            ENV['APPSIGNAL_APP_ENV'] = 'env_test'
            sample.run
            ENV.delete('APPSIGNAL_APP_ENV')
          end


          its(:env) { should == 'env_test' }
        end
      end

      context "agent" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.agent }

        it { should be_a(Appsignal::Agent) }
      end

      context "listener middleware" do
        it "should have added the listener middleware" do
          expect( app.middleware ).to receive(:insert_before).with(
            ActionDispatch::RemoteIp,
            Appsignal::Rack::Listener
          )
        end

        context "when frontend_error_catching is enabled" do
          let(:config) do
            Appsignal::Config.new(
              project_fixture_path,
              'test',
              :name => 'MyApp',
              :enable_frontend_error_catching => true
            )
          end

          before do
            Appsignal.stub(:config => config)
          end

          it "should have added the listener and JSExceptionCatcher middleware" do
            expect( app.middleware ).to receive(:insert_before).with(
              ActionDispatch::RemoteIp,
              Appsignal::Rack::Listener
            )

            expect( app.middleware ).to receive(:insert_before).with(
              Appsignal::Rack::Listener,
              Appsignal::Rack::JSExceptionCatcher
            )
          end
        end

        after { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
      end
    end
  end
end
