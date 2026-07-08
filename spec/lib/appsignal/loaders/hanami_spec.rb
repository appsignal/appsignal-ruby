if DependencyHelper.hanami_present?
  describe "Appsignal::Loaders::HanamiLoader" do
    describe "#on_load" do
      it "registers Hanami default config" do
        load_loader(:hanami)

        expect(Appsignal::Config.loader_defaults).to include(
          :name => :hanami,
          :root_path => Dir.pwd,
          :env => :test,
          :options => {
            :ignore_errors => [
              "Hanami::Router::NotAllowedError",
              "Hanami::Router::NotFoundError"
            ]
          }
        )
      end
    end

    describe "#on_start" do
      before do
        allow(::Hanami::Action).to receive(:prepend)
        load_loader(:hanami)
        start_loader(:hanami)
      end
      after { uninstall_hanami_middleware }

      def uninstall_hanami_middleware
        middleware_stack = ::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX]
        middleware_stack.delete_if do |middleware|
          [Appsignal::Rack::HanamiMiddleware, Appsignal::Rack::EventMiddleware].include?(middleware.first)
        end
      end

      it "adds the instrumentation middleware to Sinatra::Base" do
        expect(::Hanami.app.config.middleware.stack[::Hanami::Router::DEFAULT_PREFIX])
          .to include(
            [Appsignal::Rack::EventMiddleware, [],
             *hanami_middleware_options],
            [Appsignal::Rack::HanamiMiddleware, [], *hanami_middleware_options]
          )
      end

      if DependencyHelper.hanami2_2_present?
        it "does not prepend a monkeypatch integration to Hanami::Action" do
          expect(::Hanami::Action).to_not have_received(:prepend)
            .with(Appsignal::Loaders::HanamiLoader::HanamiIntegration)
        end
      else
        it "prepends the integration to Hanami::Action" do
          expect(::Hanami::Action).to have_received(:prepend)
            .with(Appsignal::Loaders::HanamiLoader::HanamiIntegration)
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

    describe "Appsignal::Loaders::HanamiLoader::HanamiIntegration" do
      let(:transaction) { http_request_transaction }
      let(:app) { HanamiApp::Actions::Books::Index }
      before do
        expect(::Hanami.app.config).to receive(:root).and_return(project_fixture_path)
        Appsignal.load(:hanami)
      end

      def make_request(env)
        action = app.new
        action.call(env)
      end

      describe "#call" do
        context "without an active transaction" do
          let(:env) { {} }

          describe "does not set the action name" do
            def perform
              make_request(env)
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              expect(transaction).to_not have_action
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform
              transaction.complete

              expect(root_span.attributes).to_not have_key("appsignal.action_name")
            end
          end
        end

        context "with an active transaction" do
          let(:env) { { Appsignal::Rack::APPSIGNAL_TRANSACTION => transaction } }

          if DependencyHelper.hanami2_2_present?
            # The action name is set by the middleware instead.
            describe "does not set an action name on the transaction" do
              def perform
                make_request(env)
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform

                expect(transaction).to_not have_action
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform
                transaction.complete

                expect(root_span.attributes).to_not have_key("appsignal.action_name")
              end
            end
          else
            describe "sets action name on the transaction" do
              def perform
                make_request(env)
              end

              it "in agent mode", :agent_mode do
                start_agent
                perform

                expect(transaction).to have_action("HanamiApp::Actions::Books::Index")
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                perform
                transaction.complete

                expect(root_span.name).to eq("HanamiApp::Actions::Books::Index")
                expect(root_span.attributes["appsignal.action_name"])
                  .to eq("HanamiApp::Actions::Books::Index")
              end
            end
          end
        end
      end
    end
  end
end
