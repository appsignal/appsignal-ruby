if DependencyHelper.rails_present?
  describe Appsignal::Integrations::Railtie do
    context "after initializing the app" do
      it "should call initialize_appsignal" do
        expect(Appsignal::Integrations::Railtie).to receive(:initialize_appsignal)

        MyApp::Application.config.root = project_fixture_path
        MyApp::Application.initialize!
      end
    end

    describe "#initialize_appsignal" do
      let(:app) { MyApp::Application }
      before { allow(app.middleware).to receive(:insert_before).and_return(true) }

      describe ".logger" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.logger }

        it { is_expected.to be_a Logger }
      end

      describe ".config" do
        let(:config) { Appsignal.config }

        describe "basic configuration" do
          before { Appsignal::Integrations::Railtie.initialize_appsignal(app) }

          it { expect(config).to be_a(Appsignal::Config) }

          it "sets the root_path" do
            expect(config.root_path).to eq Pathname.new(project_fixture_path)
          end

          it "sets the detected environment" do
            expect(config.env).to eq "test"
          end

          it "loads the app name" do
            expect(config[:name]).to eq "TestApp"
          end

          it "sets the log_path based on the root_path" do
            expect(config[:log_path]).to eq Pathname.new(File.join(project_fixture_path, "log"))
          end
        end

        context "with APPSIGNAL_APP_ENV ENV var set" do
          before do
            ENV["APPSIGNAL_APP_ENV"] = "env_test"
            Appsignal::Integrations::Railtie.initialize_appsignal(app)
          end

          it "uses the environment variable value as the environment" do
            expect(config.env).to eq "env_test"
          end
        end
      end

      describe ".initial_config" do
        before { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        let(:config) { Appsignal.config.initial_config }

        it "returns the initial config" do
          expect(config[:name]).to eq "MyApp"
        end
      end

      context "listener middleware" do
        it "should have added the listener middleware" do
          expect(app.middleware).to receive(:insert_before).with(
            ActionDispatch::RemoteIp,
            Appsignal::Rack::RailsInstrumentation
          )
        end

        context "when frontend_error_catching is enabled" do
          let(:config) do
            Appsignal::Config.new(
              project_fixture_path,
              "test",
              :name => "MyApp",
              :enable_frontend_error_catching => true
            )
          end

          before do
            allow(Appsignal).to receive(:config).and_return(config)
          end

          it "should have added the listener and JSExceptionCatcher middleware" do
            expect(app.middleware).to receive(:insert_before).with(
              ActionDispatch::RemoteIp,
              Appsignal::Rack::RailsInstrumentation
            )

            expect(app.middleware).to receive(:insert_before).with(
              Appsignal::Rack::RailsInstrumentation,
              Appsignal::Rack::JSExceptionCatcher
            )
          end
        end

        after { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
      end
    end
  end
end
