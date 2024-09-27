if DependencyHelper.rails_present?
  require "action_mailer"

  describe Appsignal::Integrations::Railtie do
    include RailsHelper
    before { Appsignal.clear! }
    after { clear_rails_error_reporter! }

    def expect_middleware_to_match(middleware, klass, args)
      expect(middleware.klass).to eq(klass)
      expect(middleware.args).to match(args)
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

          expect(Appsignal.config.root_path).to eq(Pathname.new(rails_project_fixture_path))
        end

        it "loads the Rails app name in the initial config" do
          initialize_railtie(event)

          rails_defaults = Appsignal::Config.loader_defaults
            .find { |loader| loader[:name] == :rails }
          expect(rails_defaults[:options][:name]).to eq("MyApp")
          expect(rails_defaults[:options][:log_path])
            .to eq(Pathname.new(File.join(rails_project_fixture_path, "log")))
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

          middlewares = MyApp::Application.middleware
          expect_middleware_to_match(
            middlewares.find { |m| m.klass == ::Rack::Events },
            ::Rack::Events,
            [[instance_of(Appsignal::Rack::EventHandler)]]
          )
          expect_middleware_to_match(
            middlewares.find { |m| m.klass == Appsignal::Rack::RailsInstrumentation },
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
      end
    end

    if Rails.respond_to?(:error)
      describe "Rails error reporter" do
        before { start_agent }
        around { |example| keep_transactions { example.run } }

        it "reports the error when the error is not handled (reraises the error)" do
          with_rails_error_reporter do
            expect do
              Rails.error.record { raise ExampleStandardError, "error message" }
            end.to raise_error(ExampleStandardError, "error message")
          end

          expect(last_transaction).to have_error("ExampleStandardError", "error message")
        end

        it "reports the error when the error is handled (not reraised)" do
          with_rails_error_reporter do
            Rails.error.handle { raise ExampleStandardError, "error message" }
          end

          expect(last_transaction).to have_error("ExampleStandardError", "error message")
        end

        context "Sidekiq internal errors" do
          before do
            require "sidekiq"
            require "sidekiq/job_retry"
          end

          it "ignores Sidekiq::JobRetry::Handled errors" do
            with_rails_error_reporter do
              Rails.error.handle { raise Sidekiq::JobRetry::Handled, "error message" }
            end

            expect(last_transaction).to_not have_error
          end

          it "ignores Sidekiq::JobRetry::Skip errors" do
            with_rails_error_reporter do
              Rails.error.handle { raise Sidekiq::JobRetry::Skip, "error message" }
            end

            expect(last_transaction).to_not have_error
          end

          it "doesn't crash when no Sidekiq error classes are found" do
            hide_const("Sidekiq::JobRetry")
            with_rails_error_reporter do
              Rails.error.handle { raise ExampleStandardError, "error message" }
            end

            expect(last_transaction).to have_error("ExampleStandardError", "error message")
          end
        end

        context "when no transaction is active" do
          it "reports the error on a new transaction" do
            with_rails_error_reporter do
              expect do
                Rails.error.handle { raise ExampleStandardError, "error message" }
              end.to change { created_transactions.count }.by(1)

              transaction = last_transaction
              expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)
              expect(transaction).to_not have_action
              expect(transaction).to have_error("ExampleStandardError", "error message")
            end
          end
        end

        context "when a transaction is active" do
          it "reports the error on the transaction when a transaction is active" do
            current_transaction = http_request_transaction
            current_transaction.set_namespace "custom"
            current_transaction.set_action "CustomAction"
            current_transaction.add_tags(:duplicated_tag => "duplicated value")

            with_rails_error_reporter do
              with_current_transaction current_transaction do
                Rails.error.handle { raise ExampleStandardError, "error message" }
                expect do
                  current_transaction.complete
                end.to_not(change { created_transactions.count })

                transaction = current_transaction
                expect(transaction).to have_namespace("custom")
                expect(transaction).to have_action("CustomAction")
                expect(transaction).to have_error("ExampleStandardError", "error message")
                expect(transaction).to include_tags(
                  "reported_by" => "rails_error_reporter",
                  "duplicated_tag" => "duplicated value",
                  "severity" => "warning"
                )
              end
            end
          end

          context "when the current transaction has an error" do
            it "reports the error on a new transaction" do
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

            it "reports the error on a new transaction with the given context" do
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
          end

          it "overwrites duplicate tags with tags from context" do
            current_transaction = http_request_transaction
            current_transaction.add_tags(:tag1 => "duplicated value")

            with_rails_error_reporter do
              with_current_transaction current_transaction do
                given_context = { :tag1 => "value1", :tag2 => "value2" }
                Rails.error.handle(:context => given_context) { raise ExampleStandardError }
                current_transaction.complete

                expect(current_transaction).to include_tags(
                  "reported_by" => "rails_error_reporter",
                  "tag1" => "value1",
                  "tag2" => "value2",
                  "severity" => "warning"
                )
              end
            end
          end

          it "sets namespace, action and custom data with values from context" do
            current_transaction = http_request_transaction
            current_transaction.set_namespace "custom"
            current_transaction.set_action "CustomAction"

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

                expect(current_transaction).to have_namespace("context")
                expect(current_transaction).to have_action("ContextAction")
                expect(current_transaction).to include_custom_data("data" => "context data")
              end
            end
          end
        end

        if DependencyHelper.rails7_1_present?
          it "sets the namespace to 'runner' if the source is the Rails runner" do
            expect do
              with_rails_error_reporter do
                expect do
                  Rails.error.record(:source => "application.runner.railties") do
                    raise ExampleStandardError, "error message"
                  end
                end.to raise_error(ExampleStandardError, "error message")
              end
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
        end

        it "sets the error context as tags" do
          given_context = {
            :appsignal => { :something => "not used" }, # Not set as tag
            :tag1 => "value1",
            :tag2 => "value2"
          }
          with_rails_error_reporter do
            Rails.error.handle(:context => given_context) { raise ExampleStandardError }
          end

          expect(last_transaction).to include_tags(
            "reported_by" => "rails_error_reporter",
            "tag1" => "value1",
            "tag2" => "value2",
            "severity" => "warning"
          )
        end
      end
    end
  end
end
