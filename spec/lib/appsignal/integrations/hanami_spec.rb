# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  describe "Hanami integration" do
    require "appsignal/integrations/hanami"

    before do
      uninstall_hanami_middleware
    end

    def uninstall_hanami_middleware
      middleware_stack = ::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX]
      middleware_stack.delete_if do |middleware|
        middleware.first == Appsignal::Rack::HanamiMiddleware ||
          middleware.first == Rack::Events
      end
    end

    describe Appsignal::Integrations::HanamiPlugin do
      it "starts AppSignal on init" do
        expect(Appsignal).to receive(:start)
        expect(Appsignal).to receive(:start_logger)
        Appsignal::Integrations::HanamiPlugin.init
      end

      it "prepends the integration to Hanami::Action" do
        allow(Appsignal).to receive(:active?).and_return(true)
        Appsignal::Integrations::HanamiPlugin.init
        expect(::Hanami::Action.included_modules)
          .to include(Appsignal::Integrations::HanamiIntegration)
      end

      it "adds middleware to the Hanami app" do
        allow(Appsignal).to receive(:active?).and_return(true)
        Appsignal::Integrations::HanamiPlugin.init

        expect(::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX])
          .to include(
            [Rack::Events, [[kind_of(Appsignal::Rack::EventHandler)]], nil],
            [Appsignal::Rack::HanamiMiddleware, [], nil]
          )
      end

      context "when not active" do
        before { allow(Appsignal).to receive(:active?).and_return(false) }

        it "does not prepend the integration to Hanami::Action" do
          Appsignal::Integrations::HanamiPlugin.init
          expect(::Hanami::Action).to_not receive(:prepend)
            .with(Appsignal::Integrations::HanamiIntegration)
        end

        it "does not add the middleware to the Hanami app" do
          Appsignal::Integrations::HanamiPlugin.init

          middleware_stack = ::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX]
          expect(middleware_stack).to_not include(
            [Rack::Events, [[kind_of(Appsignal::Rack::EventHandler)]], nil]
          )
          expect(middleware_stack).to_not include(
            [Appsignal::Rack::HanamiMiddleware, [], nil]
          )
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

    describe Appsignal::Integrations::HanamiIntegration do
      let(:transaction) { http_request_transaction }
      around { |example| keep_transactions { example.run } }
      before(:context) { start_agent }
      before do
        allow(Appsignal).to receive(:active?).and_return(true)
        Appsignal::Integrations::HanamiPlugin.init
      end

      def make_request(env, app: HanamiApp::Actions::Books::Index)
        action = app.new
        action.call(env)
      end

      describe "#call" do
        context "without an active transaction" do
          let(:env) { {} }

          it "does not set the action name" do
            make_request(env)

            expect(transaction.to_h).to include(
              "action" => nil
            )
          end
        end

        context "with an active transaction" do
          let(:env) { { Appsignal::Rack::APPSIGNAL_TRANSACTION => transaction } }

          it "sets action name on the transaction" do
            make_request(env)

            expect(transaction.to_h).to include(
              "action" => "HanamiApp::Actions::Books::Index"
            )
          end
        end
      end
    end
  end
end
