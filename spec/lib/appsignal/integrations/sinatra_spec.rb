if DependencyHelper.sinatra_present?
  require "appsignal/integrations/sinatra"

  def install_sinatra_integration
    load File.expand_path("lib/appsignal/integrations/sinatra.rb", project_dir)
  end

  # "Uninstall" the AppSignal integration
  def uninstall_sinatra_integration
    Sinatra::Base.instance_variable_get(:@middleware).delete_if do |middleware|
      middleware.first == Appsignal::Rack::SinatraBaseInstrumentation
    end
  end

  describe "Sinatra integration" do
    before { allow(Appsignal).to receive(:active?).and_return(true) }
    after { uninstall_sinatra_integration }

    context "Appsignal.logger" do
      subject { Appsignal.logger }

      it "sets a logger" do
        install_sinatra_integration
        is_expected.to be_a Logger
      end
    end

    describe "middleware" do
      context "when AppSignal is not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not add the instrumentation middleware to Sinatra::Base" do
          install_sinatra_integration
          expect(Sinatra::Base.middleware.to_a).to_not include(
            [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
          )
        end
      end

      context "when AppSignal is active" do
        it "adds the instrumentation middleware to Sinatra::Base" do
          install_sinatra_integration
          expect(Sinatra::Base.middleware.to_a).to include(
            [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
          )
        end
      end
    end

    describe "environment" do
      subject { Appsignal.config.env }

      context "without APPSIGNAL_APP_ENV" do
        before { install_sinatra_integration }

        it "uses the app environment" do
          expect(subject).to eq("test")
        end
      end

      context "with APPSIGNAL_APP_ENV" do
        before do
          ENV["APPSIGNAL_APP_ENV"] = "env-staging"
          install_sinatra_integration
        end

        it "uses the environment variable" do
          expect(subject).to eq("env-staging")
        end
      end
    end
  end
end
