if DependencyHelper.rails_present?
  require "action_mailer"

  describe Appsignal::Integrations::Railtie do
    include RailsHelper

    before { Appsignal.clear! }
    after { clear_rails_error_reporter! }

    def expect_middleware_to_match(middleware, klass, args)
      raise "expect_middleware_to_match: No middleware found!" unless middleware

      expect(middleware.klass).to eq(klass)
      expect(middleware.args).to match(args)
    end

    # Resolve the middleware proxy stack for the given app
    # This needs to be done manually as the middleware stack on the
    # MyApp::Application constant is frozen after the initial initialization. We need
    # to test if the operations we do in the Railtie are added by resolving it.
    def resolve_middleware(app)
      middleware_stack = ActionDispatch::MiddlewareStack.new
      # Add this middleware, because our Railtie relies on it being present
      middleware_stack.use ActionDispatch::DebugExceptions
      app.middleware.merge_into(middleware_stack)
      middleware_stack
    end

    describe "on Rails app initialize!" do
      it "starts AppSignal by calling its hooks" do
        expect(Appsignal::Integrations::Railtie).to receive(:on_load).and_call_original
        expect(Appsignal::Integrations::Railtie).to receive(:after_initialize).and_call_original

        if MyApp::Application.initialized?
          run_appsignal_railtie
        else
          MyApp::Application.initialize!
        end
      end
    end

    describe "initializer" do
      let(:app) { MyApp::Application.new }
      before do
        # Make sure it's initialized at least once
        MyApp::Application.initialize!
        Appsignal.clear!
      end

      def initialize_railtie(event)
        MyApp::Application.config.root = rails_project_fixture_path
        case event
        when :on_load
          described_class.on_load(app)
        when :after_initialize
          # Must call both so no steps are missed
          described_class.on_load(app)
          described_class.after_initialize(app)
        when :only_after_initialize
          described_class.after_initialize(app)
        else
          raise "Unsupported test event '#{event}'"
        end
      end

      shared_examples "integrates with Rails" do
        it "starts AppSignal" do
          initialize_railtie(event)

          expect(Appsignal.active?).to be_truthy
        end

        it "sets the detected environment" do
          initialize_railtie(event)

          expect(Appsignal.config.env).to eq("test")
        end

        it "uses the APPSIGNAL_APP_ENV environment variable value as the environment" do
          ENV["APPSIGNAL_APP_ENV"] = "env_test"
          initialize_railtie(event)

          expect(Appsignal.config.env).to eq "env_test"
        end

        it "sets the Rails app path as root_path" do
          initialize_railtie(event)

          expect(Appsignal.config.root_path).to eq(rails_project_fixture_path)
        end

        it "loads the Rails app name in the initial config" do
          initialize_railtie(event)

          rails_defaults = Appsignal::Config.loader_defaults
            .find { |loader| loader[:name] == :rails }
          expect(rails_defaults[:options][:name]).to eq("MyApp")
          expect(rails_defaults[:options][:log_path])
            .to eq(Pathname.new(File.join(rails_project_fixture_path, "log")))
          expect(rails_defaults[:options][:ignore_actions])
            .to eq(["Rails::HealthController#show"])
        end

        it "loads the app name from the project's appsignal.yml file" do
          initialize_railtie(event)

          expect(Appsignal.config[:name]).to eq "TestApp"
        end

        it "sets the log_path based on the root_path" do
          initialize_railtie(event)

          expect(Appsignal.config[:log_path])
            .to eq(Pathname.new(File.join(rails_project_fixture_path, "log")))
        end

        it "adds the middleware" do
          initialize_railtie(event)

          middleware_stack = resolve_middleware(app)
          expect_middleware_to_match(
            middleware_stack.find { |m| m.klass == Appsignal::Rack::EventMiddleware },
            Appsignal::Rack::EventMiddleware,
            []
          )
          expect_middleware_to_match(
            middleware_stack.find { |m| m.klass == Appsignal::Rack::RailsInstrumentation },
            Appsignal::Rack::RailsInstrumentation,
            []
          )
        end

        if Rails.respond_to?(:error)
          context "when Rails listens to `error`" do
            class ErrorReporterMock
              attr_reader :subscribers

              def initialize
                @subscribers = []
              end

              def subscribe(subscriber)
                @subscribers << subscriber
              end
            end

            let(:error_reporter) { ErrorReporterMock.new }
            before do
              allow(Rails).to receive(:error).and_return(error_reporter)
            end

            context "when enable_rails_error_reporter is enabled" do
              it "subscribes to the error reporter" do
                initialize_railtie(event)

                expect(error_reporter.subscribers)
                  .to eq([Appsignal::Integrations::RailsErrorReporterSubscriber])
              end
            end

            context "when enable_rails_error_reporter is disabled" do
              it "does not subscribe to the error reporter" do
                ENV["APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER"] = "false"
                initialize_railtie(event)

                expect(error_reporter.subscribers)
                  .to_not eq([Appsignal::Integrations::RailsErrorReporterSubscriber])
              end
            end
          end
        else
          context "when Rails does not listen to `error`" do
            it "does not error trying to subscribe to the error reporter" do
              initialize_railtie(event)
            end
          end
        end
      end

      describe ".on_load" do
        let(:event) { :on_load }

        context "when start_at == :on_load" do
          include_examples "integrates with Rails"
        end

        context "when start_at == :after_initialize" do
          it "does not start AppSignal" do
            app.config.appsignal.start_at = :after_initialize
            initialize_railtie(event)

            expect(Appsignal.started?).to be_falsy
            expect(Appsignal.config).to be_nil
          end
        end

        it "doesn't add the middleware when AppSignal is not started" do
          allow(Appsignal).to receive(:started?).and_return(false)
          initialize_railtie(event)

          middleware_stack = resolve_middleware(app)
          expect(middleware_stack.find do |m|
                   m.klass == Appsignal::Rack::EventMiddleware
                 end).to be_nil
          expect(middleware_stack.find { |m| m.klass == Appsignal::Rack::RailsInstrumentation })
            .to be_nil
        end
      end

      describe ".after_initialize" do
        let(:event) { :after_initialize }

        context "when start_at == :after_initialize" do
          before do
            app.config.appsignal.start_at = :after_initialize
          end

          include_examples "integrates with Rails"
        end

        context "when start_at == :on_load" do
          before do
            Appsignal.clear_started!
            Appsignal.clear_config!
          end

          it "does not start AppSignal" do
            app.config.appsignal.start_at = :on_load
            initialize_railtie(:only_after_initialize)

            expect(Appsignal.started?).to be_falsy
            expect(Appsignal.config).to be_nil
          end
        end

        it "adds the middleware even when AppSignal is not started" do
          allow(Appsignal).to receive(:started?).and_return(false)
          initialize_railtie(event)

          middleware_stack = resolve_middleware(app)
          expect_middleware_to_match(
            middleware_stack.find { |m| m.klass == Appsignal::Rack::EventMiddleware },
            Appsignal::Rack::EventMiddleware,
            []
          )
          expect_middleware_to_match(
            middleware_stack.find { |m| m.klass == Appsignal::Rack::RailsInstrumentation },
            Appsignal::Rack::RailsInstrumentation,
            []
          )
        end
      end
    end

    if Rails.respond_to?(:error)
      describe "Rails error reporter" do
        describe "reports the error when the error is not handled (reraises the error)" do
          def perform
            with_rails_error_reporter do
              expect do
                Rails.error.record { raise ExampleStandardError, "error message" }
              end.to raise_error(ExampleStandardError, "error message")
            end
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to have_error("ExampleStandardError", "error message")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
            expect(event.attributes["exception.message"]).to eq("error message")
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            expect(scope_of(root_span)).to eq(["appsignal-ruby-rails", Appsignal::VERSION])
          end
        end

        describe "reports the error when the error is handled (not reraised)" do
          def perform
            with_rails_error_reporter do
              Rails.error.handle { raise ExampleStandardError, "error message" }
            end
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to have_error("ExampleStandardError", "error message")
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            event = root_span.events.find { |e| e.name == "exception" }
            expect(event).not_to be_nil
            expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
            expect(event.attributes["exception.message"]).to eq("error message")
            expect(event.attributes["exception.stacktrace"]).to be_a(String)
            expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
            expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
          end
        end

        context "Sidekiq internal errors" do
          before do
            require "sidekiq"
            require "sidekiq/job_retry"
          end

          describe "ignores Sidekiq::JobRetry::Handled errors" do
            def perform
              with_rails_error_reporter do
                Rails.error.handle { raise Sidekiq::JobRetry::Handled, "error message" }
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              expect(last_transaction).to_not have_error
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(exception_events).to be_empty
            end
          end

          describe "ignores Sidekiq::JobRetry::Skip errors" do
            def perform
              with_rails_error_reporter do
                Rails.error.handle { raise Sidekiq::JobRetry::Skip, "error message" }
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              expect(last_transaction).to_not have_error
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              expect(exception_events).to be_empty
            end
          end

          describe "doesn't crash when no Sidekiq error classes are found" do
            def perform
              hide_const("Sidekiq::JobRetry")
              with_rails_error_reporter do
                Rails.error.handle { raise ExampleStandardError, "error message" }
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              perform

              expect(last_transaction).to have_error("ExampleStandardError", "error message")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              perform

              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            end
          end
        end

        context "when no transaction is active" do
          describe "reports the error on a new transaction" do
            def perform
              with_rails_error_reporter do
                Rails.error.handle { raise ExampleStandardError, "error message" }
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              expect do
                perform
              end.to change { created_transactions.count }.by(1)

              transaction = last_transaction
              expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
              expect(transaction).to_not have_action
              expect(transaction).to have_error("ExampleStandardError", "error message")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              expect do
                perform
              end.to change { created_transactions.count }.by(1)

              expect(root_span.kind).to eq(:server)
              expect(root_span.attributes["appsignal.namespace"])
                .to eq("web")
              expect(root_span.attributes).to_not have_key("appsignal.action_name")
              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
            end
          end
        end

        context "when a transaction is active" do
          describe "reports the error on the transaction when a transaction is active" do
            def perform(current_transaction)
              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  Rails.error.handle { raise ExampleStandardError, "error message" }
                end
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"
              current_transaction.add_tags(:duplicated_tag => "duplicated value")

              expect do
                perform(current_transaction)
              end.to_not(change { created_transactions.count })
              current_transaction.complete

              expect(current_transaction).to have_namespace("custom")
              expect(current_transaction).to have_action("CustomAction")
              expect(current_transaction).to have_error("ExampleStandardError", "error message")
              expect(current_transaction).to include_tags(
                "reported_by" => "rails_error_reporter",
                "duplicated_tag" => "duplicated value",
                "severity" => "warning"
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"
              current_transaction.add_tags(:duplicated_tag => "duplicated value")

              expect do
                perform(current_transaction)
              end.to_not(change { created_transactions.count })
              current_transaction.complete

              expect(root_span.attributes["appsignal.namespace"]).to eq("custom")
              expect(root_span.attributes["appsignal.action_name"]).to eq("CustomAction")
              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
              expect(root_span.attributes["appsignal.tag.reported_by"])
                .to eq("rails_error_reporter")
              expect(root_span.attributes["appsignal.tag.duplicated_tag"])
                .to eq("duplicated value")
              expect(root_span.attributes["appsignal.tag.severity"]).to eq("warning")
            end
          end

          context "when the current transaction has an error" do
            describe "reports the error (new transaction in agent, span in collector)" do
              it "in agent mode", :agent_mode do
                start_agent
                current_transaction = http_request_transaction
                current_transaction.set_namespace "custom"
                current_transaction.set_action "CustomAction"
                current_transaction.add_tags(:duplicated_tag => "duplicated value")
                current_transaction.add_error(ExampleStandardError.new("error message"))

                with_rails_error_reporter do
                  with_current_transaction current_transaction do
                    Rails.error.handle { raise ExampleStandardError, "other message" }
                    expect do
                      current_transaction.complete
                    end.to change { created_transactions.count }.by(1)

                    expect(current_transaction)
                      .to_not include_tags("reported_by" => "rails_error_reporter")

                    transaction = last_transaction
                    expect(transaction).to have_namespace("custom")
                    expect(transaction).to have_action("CustomAction")
                    expect(transaction).to have_error("ExampleStandardError", "other message")
                    expect(transaction).to include_tags(
                      "reported_by" => "rails_error_reporter",
                      "duplicated_tag" => "duplicated value",
                      "severity" => "warning"
                    )
                  end
                end
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                current_transaction = http_request_transaction
                current_transaction.set_namespace "custom"
                current_transaction.set_action "CustomAction"
                current_transaction.add_tags(:duplicated_tag => "duplicated value")
                current_transaction.add_error(ExampleStandardError.new("error message"))

                with_rails_error_reporter do
                  with_current_transaction current_transaction do
                    Rails.error.handle { raise ExampleStandardError, "other message" }
                    # In collector mode both errors collapse onto one span — no
                    # duplicate transaction is created.
                    expect do
                      current_transaction.complete
                    end.to_not(change { created_transactions.count })

                    expect(root_span.attributes["appsignal.namespace"]).to eq("custom")
                    expect(root_span.attributes["appsignal.action_name"]).to eq("CustomAction")
                    # Both errors collapse onto one root span as two exception events.
                    root_spans = span_exporter.finished_spans.select do |s|
                      [:server, :consumer].include?(s.kind)
                    end
                    expect(root_spans.size).to eq(1)
                    events = root_spans.first.events.select { |e| e.name == "exception" }
                    expect(events.map { |e| e.attributes["exception.message"] })
                      .to contain_exactly("error message", "other message")
                    expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
                    expect(root_span.attributes["appsignal.tag.reported_by"])
                      .to eq("rails_error_reporter")
                    expect(root_span.attributes["appsignal.tag.duplicated_tag"])
                      .to eq("duplicated value")
                    expect(root_span.attributes["appsignal.tag.severity"]).to eq("warning")
                  end
                end
              end
            end

            describe "reports the error on a new transaction with the given context (agent) / merges context onto the span (collector)" do # rubocop:disable Layout/LineLength
              it "in agent mode", :agent_mode do
                start_agent
                current_transaction = http_request_transaction
                current_transaction.set_namespace "custom"
                current_transaction.set_action "CustomAction"
                current_transaction.add_tags(:duplicated_tag => "duplicated value")
                current_transaction.add_custom_data(:original => "custom value")
                current_transaction.add_error(ExampleStandardError.new("error message"))

                with_rails_error_reporter do
                  with_current_transaction current_transaction do
                    given_context = {
                      :appsignal => {
                        :namespace => "context",
                        :action => "ContextAction",
                        :custom_data => { :context => "context data" }

                      }
                    }
                    Rails.error.handle(:context => given_context) do
                      raise ExampleStandardError, "other message"
                    end
                    expect do
                      current_transaction.complete
                    end.to change { created_transactions.count }.by(1)

                    transaction = last_transaction
                    expect(transaction).to have_namespace("context")
                    expect(transaction).to have_action("ContextAction")
                    expect(transaction).to have_error("ExampleStandardError", "other message")
                    expect(transaction).to include_tags(
                      "reported_by" => "rails_error_reporter",
                      "duplicated_tag" => "duplicated value",
                      "severity" => "warning"
                    )
                    expect(transaction).to include_custom_data(
                      "original" => "custom value",
                      "context" => "context data"
                    )
                  end
                end
              end

              it "in collector mode", :collector_mode do
                start_collector_agent
                current_transaction = http_request_transaction
                current_transaction.set_namespace "custom"
                current_transaction.set_action "CustomAction"
                current_transaction.add_tags(:duplicated_tag => "duplicated value")
                current_transaction.add_custom_data(:original => "custom value")
                current_transaction.add_error(ExampleStandardError.new("error message"))

                with_rails_error_reporter do
                  with_current_transaction current_transaction do
                    given_context = {
                      :appsignal => {
                        :namespace => "context",
                        :action => "ContextAction",
                        :custom_data => { :context => "context data" }
                      }
                    }
                    Rails.error.handle(:context => given_context) do
                      raise ExampleStandardError, "other message"
                    end
                    # In collector mode both errors collapse onto one span — no
                    # duplicate transaction is created. The reporter's block
                    # overrides namespace/action on the existing span.
                    expect do
                      current_transaction.complete
                    end.to_not(change { created_transactions.count })

                    expect(root_span.attributes["appsignal.namespace"]).to eq("context")
                    expect(root_span.attributes["appsignal.action_name"]).to eq("ContextAction")
                    # Both errors collapse onto one root span as two exception events.
                    root_spans = span_exporter.finished_spans.select do |s|
                      [:server, :consumer].include?(s.kind)
                    end
                    expect(root_spans.size).to eq(1)
                    events = root_spans.first.events.select { |e| e.name == "exception" }
                    expect(events.map { |e| e.attributes["exception.message"] })
                      .to contain_exactly("error message", "other message")
                    expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
                    expect(root_span.attributes["appsignal.tag.reported_by"])
                      .to eq("rails_error_reporter")
                    expect(root_span.attributes["appsignal.tag.duplicated_tag"])
                      .to eq("duplicated value")
                    expect(root_span.attributes["appsignal.tag.severity"]).to eq("warning")
                    custom_data = JSON.parse(root_span.attributes["appsignal.custom_data"])
                    expect(custom_data).to include(
                      "original" => "custom value",
                      "context" => "context data"
                    )
                  end
                end
              end
            end
          end

          describe "overwrites duplicate tags with tags from context" do
            def perform(current_transaction)
              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  given_context = { :tag1 => "value1", :tag2 => "value2" }
                  Rails.error.handle(:context => given_context) { raise ExampleStandardError }
                  current_transaction.complete
                end
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              current_transaction = http_request_transaction
              current_transaction.add_tags(:tag1 => "duplicated value")

              perform(current_transaction)

              expect(current_transaction).to include_tags(
                "reported_by" => "rails_error_reporter",
                "tag1" => "value1",
                "tag2" => "value2",
                "severity" => "warning"
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              current_transaction = http_request_transaction
              current_transaction.add_tags(:tag1 => "duplicated value")

              perform(current_transaction)

              expect(root_span.attributes["appsignal.tag.reported_by"])
                .to eq("rails_error_reporter")
              expect(root_span.attributes["appsignal.tag.tag1"]).to eq("value1")
              expect(root_span.attributes["appsignal.tag.tag2"]).to eq("value2")
              expect(root_span.attributes["appsignal.tag.severity"]).to eq("warning")
            end
          end

          describe "sets namespace, action and custom data with values from context" do
            def perform(current_transaction)
              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  given_context = {
                    :appsignal => {
                      :namespace => "context",
                      :action => "ContextAction",
                      :custom_data => { :data => "context data" }
                    }
                  }
                  Rails.error.handle(:context => given_context) { raise ExampleStandardError }
                  current_transaction.complete
                end
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"

              perform(current_transaction)

              expect(current_transaction).to have_namespace("context")
              expect(current_transaction).to have_action("ContextAction")
              expect(current_transaction).to include_custom_data("data" => "context data")
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"

              perform(current_transaction)

              expect(root_span.attributes["appsignal.namespace"]).to eq("context")
              expect(root_span.attributes["appsignal.action_name"]).to eq("ContextAction")
              expect(JSON.parse(root_span.attributes["appsignal.custom_data"]))
                .to include("data" => "context data")
            end
          end
        end

        if DependencyHelper.rails7_1_present?
          describe "sets the namespace to 'runner' if the source is the Rails runner" do
            def perform
              with_rails_error_reporter do
                expect do
                  Rails.error.record(:source => "application.runner.railties") do
                    raise ExampleStandardError, "error message"
                  end
                end.to raise_error(ExampleStandardError, "error message")
              end
            end

            it "in agent mode", :agent_mode do
              start_agent
              expect do
                perform
              end.to change { created_transactions.count }.by(1)

              transaction = last_transaction
              expect(transaction).to have_namespace("runner")
              expect(transaction).to_not have_action
              expect(transaction).to have_error("ExampleStandardError", "error message")
              expect(transaction).to include_tags(
                "reported_by" => "rails_error_reporter",
                "source" => "application.runner.railties"
              )
            end

            it "in collector mode", :collector_mode do
              start_collector_agent
              expect do
                perform
              end.to change { created_transactions.count }.by(1)

              expect(root_span.kind).to eq(:server)
              expect(root_span.attributes["appsignal.namespace"]).to eq("runner")
              expect(root_span.attributes).to_not have_key("appsignal.action_name")
              event = root_span.events.find { |e| e.name == "exception" }
              expect(event).not_to be_nil
              expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
              expect(event.attributes["exception.message"]).to eq("error message")
              expect(event.attributes["exception.stacktrace"]).to be_a(String)
              expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
              expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
              expect(root_span.attributes["appsignal.tag.reported_by"])
                .to eq("rails_error_reporter")
              expect(root_span.attributes["appsignal.tag.source"])
                .to eq("application.runner.railties")
            end
          end
        end

        describe "sets the error context as tags" do
          def perform
            given_context = {
              :appsignal => { :something => "not used" }, # Not set as tag
              :tag1 => "value1",
              :tag2 => "value2"
            }
            with_rails_error_reporter do
              Rails.error.handle(:context => given_context) { raise ExampleStandardError }
            end
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(last_transaction).to include_tags(
              "reported_by" => "rails_error_reporter",
              "tag1" => "value1",
              "tag2" => "value2",
              "severity" => "warning"
            )
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            expect(root_span.attributes["appsignal.tag.reported_by"])
              .to eq("rails_error_reporter")
            expect(root_span.attributes["appsignal.tag.tag1"]).to eq("value1")
            expect(root_span.attributes["appsignal.tag.tag2"]).to eq("value2")
            expect(root_span.attributes["appsignal.tag.severity"]).to eq("warning")
          end
        end
      end
    end
  end
end
