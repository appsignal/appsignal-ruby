# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  def install_hanami_integration
    load File.expand_path("lib/appsignal/integrations/hanami.rb", project_dir)
  end

  def uninstall_hanami_integration
    Hanami.app.config.middleware.stack["/"] = []
  end

  describe "Hanami integration" do
    before do
      allow(Appsignal).to receive(:active?).and_return(true)
      allow(Appsignal).to receive(:start).and_return(true)
      allow(Appsignal).to receive(:start_logger).and_return(true)

      allow(Hanami).to receive(:app).and_return(HanamiApp::App)
    end

    after { uninstall_hanami_integration }

    context "Appsignal.logger" do
      subject { Appsignal.logger }

      it "sets a logger" do
        install_hanami_integration
        is_expected.to be_a Logger
      end
    end

    describe "middleware" do
      context "when AppSignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not add the instrumentation middleware to Hanami" do
          install_hanami_integration

          expect(Hanami.app.config.middleware.stack["/"]).to_not include(
            [Appsignal::Rack::HanamiInstrumentation, [], nil]
          )
        end
      end

      context "when AppSignal is active" do
        it "adds the instrumentation middleware to Hanami" do
          install_hanami_integration

          expect(Hanami.app.config.middleware.stack["/"]).to include(
            [Appsignal::Rack::HanamiInstrumentation, [], nil]
          )
        end
      end
    end

    describe "environment" do
      subject { Appsignal.config.env }

      context "without APPSIGNAL_APP_ENV" do
        before { install_hanami_integration }

        it "uses the app environment" do
          expect(subject).to eq("test")
        end
      end

      context "with APPSIGNAL_APP_ENV" do
        before do
          ENV["APPSIGNAL_APP_ENV"] = "env-staging"
          install_hanami_integration
        end

        it "uses the environment variable" do
          expect(subject).to eq("env-staging")
        end
      end
    end
  end
end
