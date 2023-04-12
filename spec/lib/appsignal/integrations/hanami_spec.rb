# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  describe "Hanami integration" do
    require "appsignal/integrations/hanami"

    before do
      allow(Appsignal).to receive(:active?).and_return(true)
      allow(Appsignal).to receive(:start).and_return(true)
      allow(Appsignal).to receive(:start_logger).and_return(true)
    end

    describe Appsignal::Integrations::HanamiPlugin do
      it "starts AppSignal on init" do
        expect(Appsignal).to receive(:start)
      end

      it "starts the logger on init" do
        expect(Appsignal).to receive(:start_logger)
      end

      it "prepends the integration to Hanami" do
        expect(::Hanami::Action).to receive(:prepend)
          .with(Appsignal::Integrations::HanamiIntegration)
      end

      context "when not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not prepend the integration" do
          expect(::Hanami::Action).to_not receive(:prepend)
            .with(Appsignal::Integrations::HanamiIntegration)
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is provided" do
        it "uses this as the environment" do
          ENV["APPSIGNAL_APP_ENV"] = "custom"

          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::HanamiPlugin.init

          expect(Appsignal.config.env).to eq("custom")
        end
      end

      context "when APPSIGNAL_APP_ENV ENV var is not provided" do
        it "uses the Hanami environment" do
          # Reset the plugin to pull down the latest data
          Appsignal::Integrations::HanamiPlugin.init

          expect(Appsignal.config.env).to eq("test")
        end
      end

      after { Appsignal::Integrations::HanamiPlugin.init }
    end

    describe "Hanami Actions" do
      let(:env) do
        Rack::MockRequest.env_for(
          "/books",
          "router.params" => router_params,
          :method => "GET"
        )
      end

      let(:router_params) { { :foo => "bar", :baz => "qux" } }

      describe "#call", :error => false do
        it "sets params" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:params=).with(router_params)
        end

        it "sets the action name" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_action_if_nil)
            .with("HanamiApp::Actions::Books::Index")
        end

        it "sets the metadata" do
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata)
            .with("status", "200")
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata)
            .with("path", "/books")
          expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata)
            .with("method", "GET")
        end

        it "sets the queue start" do
          expect_any_instance_of(Appsignal::Transaction)
            .to receive(:set_http_or_background_queue_start)
        end

        context "with error", :error => true do
          let(:error) { HanamiApp::ExampleError }

          it "records the exception" do
            expect_any_instance_of(Appsignal::Transaction).to receive(:set_error).with(error)
          end

          it "sets the status to 500" do
            expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata)
              .with("status", "500")
            expect_any_instance_of(Appsignal::Transaction).to receive(:set_metadata).twice
          end
        end

        after(:error => false) do
          Appsignal::Integrations::HanamiPlugin.init

          action = HanamiApp::Actions::Books::Index.new
          action.call(env)
        end

        after(:error => true) do
          Appsignal::Integrations::HanamiPlugin.init

          action = HanamiApp::Actions::Books::Error.new
          expect { action.call(env) }.to raise_error(error)
        end
      end
    end
  end
end
