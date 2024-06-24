# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  describe "Hanami integration" do
    require "appsignal/integrations/hanami"

    describe Appsignal::Integrations::HanamiPlugin do
      it "starts AppSignal on init" do
        expect(Appsignal).to receive(:start)
        expect(Appsignal).to receive(:start_logger)
        Appsignal::Integrations::HanamiPlugin.init
      end

      it "prepends the integration to Hanami" do
        allow(Appsignal).to receive(:active?).and_return(true)
        Appsignal::Integrations::HanamiPlugin.init
        expect(::Hanami::Action.included_modules)
          .to include(Appsignal::Integrations::HanamiIntegration)
      end

      context "when not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not prepend the integration" do
          Appsignal::Integrations::HanamiPlugin.init
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
    end

    describe "Hanami Actions" do
      let(:env) do
        Rack::MockRequest.env_for(
          "/books",
          "router.params" => router_params,
          :method => "GET"
        )
      end
      let(:router_params) { { "foo" => "bar", "baz" => "qux" } }
      around { |example| keep_transactions { example.run } }
      before :context do
        start_agent
      end
      before do
        allow(Appsignal).to receive(:active?).and_return(true)
        Appsignal::Integrations::HanamiPlugin.init
      end

      def make_request(env, app: HanamiApp::Actions::Books::Index)
        action = app.new
        action.call(env)
      end

      describe "#call" do
        it "sets params" do
          make_request(env)

          expect(last_transaction.to_h).to include(
            "sample_data" => hash_including(
              "params" => router_params
            )
          )
        end

        it "sets the namespace and action name" do
          make_request(env)

          expect(last_transaction.to_h).to include(
            "namespace" => Appsignal::Transaction::HTTP_REQUEST,
            "action" => "HanamiApp::Actions::Books::Index"
          )
        end

        it "sets the metadata" do
          make_request(env)

          expect(last_transaction.to_h).to include(
            "metadata" => hash_including(
              "status" => "200",
              "path" => "/books",
              "method" => "GET"
            )
          )
        end

        context "with queue start header" do
          let(:queue_start_time) { fixed_time * 1_000 }
          before do
            env["HTTP_X_REQUEST_START"] = "t=#{queue_start_time.to_i}" # in milliseconds
          end

          it "sets the queue start" do
            make_request(env)

            expect(last_transaction.ext.queue_start).to eq(queue_start_time)
          end
        end

        context "with error" do
          before do
            expect do
              make_request(env, :app => HanamiApp::Actions::Books::Error)
            end.to raise_error(ExampleException)
          end

          it "records the exception" do
            expect(last_transaction.to_h).to include(
              "error" => {
                "name" => "ExampleException",
                "message" => "exception message",
                "backtrace" => kind_of(String)
              }
            )
          end

          it "sets the status to 500" do
            expect(last_transaction.to_h).to include(
              "metadata" => hash_including(
                "status" => "500"
              )
            )
          end
        end
      end
    end
  end
end
