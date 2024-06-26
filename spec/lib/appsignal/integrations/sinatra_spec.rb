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
    before do
      Appsignal.config = nil
    end
    after { uninstall_sinatra_integration }

    context "when active" do
      before { allow(Appsignal).to receive(:active?).and_return(true) }

      it "does not start AppSignal again" do
        expect(Appsignal::Config).to_not receive(:new)
        expect(Appsignal).to_not receive(:start)
        install_sinatra_integration
      end

      it "adds the instrumentation middleware to Sinatra::Base" do
        install_sinatra_integration
        expect(Sinatra::Base.middleware.to_a).to include(
          [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
        )
      end
    end

    context "when not active" do
      context "Appsignal.internal_logger" do
        subject { Appsignal.internal_logger }

        it "sets a logger" do
          install_sinatra_integration
          is_expected.to be_a Logger
        end
      end

      describe "middleware" do
        context "when AppSignal is not active" do
          it "does not add the instrumentation middleware to Sinatra::Base" do
            install_sinatra_integration
            middlewares = Sinatra::Base.middleware.to_a
            expect(middlewares).to_not include(
              [Appsignal::Rack::SinatraBaseInstrumentation, [], nil]
            )
            expect(middlewares).to_not include(
              [Rack::Events, [Appsignal::Rack::EventHandler], nil]
            )
          end
        end

        context "when the new AppSignal config is active" do
          it "adds the instrumentation middleware to Sinatra::Base" do
            ENV["APPSIGNAL_APP_NAME"] = "My Sinatra app name"
            ENV["APPSIGNAL_APP_ENV"] = "test"
            ENV["APPSIGNAL_PUSH_API_KEY"] = "my-key"

            install_sinatra_integration
            middlewares = Sinatra::Base.middleware.to_a
            expect(middlewares).to include(
              [Rack::Events, [[Appsignal::Rack::EventHandler]], nil],
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
end
