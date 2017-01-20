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

      context "logger" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.logger }

        it { is_expected.to be_a Logger }
      end

      context "config" do
        subject { Appsignal.config }
        context "basics" do
          before { Appsignal::Integrations::Railtie.initialize_appsignal(app) }

          it { is_expected.to be_a(Appsignal::Config) }

          describe '#root_path' do
            subject { super().root_path }
            it { is_expected.to eq Pathname.new(project_fixture_path) }
          end

          describe '#env' do
            subject { super().env }
            it { is_expected.to eq "test" }
          end

          describe '[:name]' do
            subject { super()[:name] }
            it { is_expected.to eq "TestApp" }
          end

          describe '[:log_path]' do
            subject { super()[:log_path] }
            it { is_expected.to eq Pathname.new(File.join(project_fixture_path, "log")) }
          end
        end

        context "initial config" do
          before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
          subject { Appsignal.config.initial_config }

          describe '[:name]' do
            subject { super()[:name] }
            it { is_expected.to eq "MyApp" }
          end
        end

        context "with APPSIGNAL_APP_ENV ENV var set" do
          before do
            expect(ENV).to receive(:fetch).with("APPSIGNAL_APP_ENV", "test").and_return("env_test")
            Appsignal::Integrations::Railtie.initialize_appsignal(app)
          end

          describe '#env' do
            subject { super().env }
            it { is_expected.to eq "env_test" }
          end
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
