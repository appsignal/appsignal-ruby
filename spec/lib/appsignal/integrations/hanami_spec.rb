# frozen_string_literal: true

if DependencyHelper.hanami2_present?
  describe "Hanami integration" do
    require "appsignal/integrations/hanami"

    before do
      Appsignal.config = nil
      allow(::Hanami::Action).to receive(:prepend)
      uninstall_hanami_middleware
      ENV["APPSIGNAL_APP_NAME"] = "hanamia-test-app"
      ENV["APPSIGNAL_APP_ENV"] = "test"
      ENV["APPSIGNAL_PUSH_API_KEY"] = "0000"
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
        expect(Appsignal.active?).to be_falsey

        Appsignal::Integrations::HanamiPlugin.init

        expect(Appsignal.active?).to be_truthy
      end

      it "prepends the integration to Hanami::Action" do
        Appsignal::Integrations::HanamiPlugin.init

        expect(::Hanami::Action)
          .to have_received(:prepend).with(Appsignal::Integrations::HanamiIntegration)
      end

      it "adds middleware to the Hanami app" do
        Appsignal::Integrations::HanamiPlugin.init

        expect(::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX])
          .to include(
            [Rack::Events, [[kind_of(Appsignal::Rack::EventHandler)]], *hanami_middleware_options],
            [Appsignal::Rack::HanamiMiddleware, [], *hanami_middleware_options]
          )
      end

      context "when not active" do
        before do
          ENV.delete("APPSIGNAL_APP_NAME")
          ENV.delete("APPSIGNAL_APP_ENV")
          ENV.delete("APPSIGNAL_PUSH_API_KEY")
        end

        it "does not prepend the integration to Hanami::Action" do
          Appsignal::Integrations::HanamiPlugin.init

          expect(::Hanami::Action).to_not have_received(:prepend)
            .with(Appsignal::Integrations::HanamiIntegration)
        end

        it "does not add the middleware to the Hanami app" do
          Appsignal::Integrations::HanamiPlugin.init

          middleware_stack = ::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX]
          expect(middleware_stack).to_not include(
            [Rack::Events, [[kind_of(Appsignal::Rack::EventHandler)]], *hanami_middleware_options]
          )
          expect(middleware_stack).to_not include(
            [Appsignal::Rack::HanamiMiddleware, [], *hanami_middleware_options]
          )
        end
      end

      context "when AppSignal is already active" do
        before do
          expect(Appsignal).to receive(:active?).at_least(1).and_return(true)
        end

        it "does not initialize AppSignal again" do
          expect(Appsignal).to_not receive(:start)

          Appsignal::Integrations::HanamiPlugin.init
        end

        it "prepends the integration to Hanami::Action" do
          Appsignal::Integrations::HanamiPlugin.init

          expect(::Hanami::Action)
            .to have_received(:prepend).with(Appsignal::Integrations::HanamiIntegration)
        end

        it "adds middleware to the Hanami app" do
          Appsignal::Integrations::HanamiPlugin.init

          expect(::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX])
            .to include(
              [
                Rack::Events,
                [[kind_of(Appsignal::Rack::EventHandler)]],
                *hanami_middleware_options
              ],
              [Appsignal::Rack::HanamiMiddleware, [], *hanami_middleware_options]
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
      let(:app) do
        Class.new(HanamiApp::Actions::Books::Index) do
          def self.name
            "HanamiApp::Actions::Books::Index::TestClass"
          end
        end
      end
      around { |example| keep_transactions { example.run } }
      before do
        ENV["APPSIGNAL_APP_NAME"] = "hanamia-test-app"
        ENV["APPSIGNAL_APP_ENV"] = "test"
        ENV["APPSIGNAL_PUSH_API_KEY"] = "0000"
        Appsignal::Integrations::HanamiPlugin.init
        allow(app).to receive(:prepend).and_call_original
        app.prepend(Appsignal::Integrations::HanamiIntegration)
      end

      def make_request(env)
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
              "action" => "HanamiApp::Actions::Books::Index::TestClass"
            )
          end
        end
      end
    end

    def hanami_middleware_options
      if DependencyHelper.hanami2_1_present?
        [{}, nil]
      else
        [nil]
      end
    end
  end
end
