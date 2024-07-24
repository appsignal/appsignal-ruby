if DependencyHelper.rails_present?
  require "action_mailer"

  describe Appsignal::Integrations::Railtie do
    include RailsHelper

    after { clear_rails_error_reporter! }

    module RailtieHelper
      def self.ensure_initialize!
        return if @initialized

        MyApp::Application.config.root = ConfigHelpers.project_fixture_path
        MyApp::Application.initialize!
        @initialized = true
      end
    end

    def expect_middleware_to_match(middleware, klass, args)
      expect(middleware.klass).to eq(klass)
      expect(middleware.args).to match(args)
    end

    describe "on Rails app initialize!" do
      it "starts AppSignal by calling its hooks" do
        expect(Appsignal::Integrations::Railtie).to receive(:on_load).and_call_original
        expect(Appsignal::Integrations::Railtie).to receive(:after_initialize).and_call_original

        RailtieHelper.ensure_initialize!
      end
    end

    describe "initializer" do
      let(:app) { MyApp::Application.new }
      before do
        RailtieHelper.ensure_initialize!
      end

      def initialize_railtie(event)
        MyApp::Application.config.root = project_fixture_path
        case event
        when :on_load
          described_class.on_load(app)
        when :after_initialize
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

        it "doesn't overwrite the config if a config is already present " do
          Appsignal._config = Appsignal::Config.new(
            Dir.pwd,
            "my_env",
            :some_config => "some value"
          )
          initialize_railtie(event)

          expect(Appsignal.config.env).to eq("my_env")
          expect(Appsignal.config.root_path).to eq(Dir.pwd)
          expect(Appsignal.config[:some_config]).to eq("some value")
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

          expect(Appsignal.config.root_path).to eq(Pathname.new(project_fixture_path))
        end

        it "loads the Rails app name in the initial config" do
          initialize_railtie(event)

          expect(Appsignal.config.initial_config[:name]).to eq "MyApp"
        end

        it "loads the app name from the project's appsignal.yml file" do
          initialize_railtie(event)

          expect(Appsignal.config[:name]).to eq "TestApp"
        end

        it "sets the log_path based on the root_path" do
          initialize_railtie(event)

          expect(Appsignal.config[:log_path])
            .to eq(Pathname.new(File.join(project_fixture_path, "log")))
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

            expect(Appsignal.active?).to be_falsy
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
          it "does not start AppSignal" do
            app.config.appsignal.start_at = :on_load
            initialize_railtie(event)

            expect(Appsignal.active?).to be_falsy
            expect(Appsignal.config).to be_nil
          end
        end
      end
    end

    if Rails.respond_to?(:error)
      describe "Rails error reporter" do
        before { start_agent }
        around { |example| keep_transactions { example.run } }

        context "when error is not handled (reraises the error)" do
          it "does nothing" do
            with_rails_error_reporter do
              expect do
                Rails.error.record { raise ExampleStandardError, "error message" }
              end.to raise_error(ExampleStandardError, "error message")
            end

            expect(created_transactions).to be_empty
          end

          if DependencyHelper.rails7_1_present?
            it "reports the error if the source is the Rails runner" do
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
              expect(transaction).to include_tags("source" => "application.runner.railties")
            end
          end
        end

        context "when error is handled (not reraised)" do
          context "when a transaction is active" do
            it "duplicates the transaction namespace, action and tags" do
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"
              current_transaction.add_tags(
                :duplicated_tag => "duplicated value"
              )

              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  Rails.error.handle { raise ExampleStandardError, "error message" }

                  transaction = last_transaction
                  expect(transaction).to have_namespace("custom")
                  expect(transaction).to have_action("CustomAction")
                  expect(transaction).to have_error("ExampleStandardError", "error message")
                  expect(transaction).to include_tags(
                    "duplicated_tag" => "duplicated value",
                    "severity" => "warning"
                  )
                end
              end
            end

            it "overwrites duplicated tags with tags from context" do
              current_transaction = http_request_transaction
              current_transaction.add_tags(:tag1 => "duplicated value")

              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  given_context = { :tag1 => "value1", :tag2 => "value2" }
                  Rails.error.handle(:context => given_context) { raise ExampleStandardError }

                  expect(last_transaction).to include_tags(
                    "tag1" => "value1",
                    "tag2" => "value2",
                    "severity" => "warning"
                  )
                end
              end
            end

            it "sends tags stored in :appsignal -> :custom_data as custom data" do
              current_transaction = http_request_transaction

              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  given_context = {
                    :appsignal => {
                      :custom_data => {
                        :array => [1, 2],
                        :hash => { :one => 1, :two => 2 }
                      }
                    }
                  }
                  Rails.error.handle(:context => given_context) { raise ExampleStandardError }

                  transaction = last_transaction
                  expect(transaction).to include_custom_data(
                    "array" => [1, 2],
                    "hash" => { "one" => 1, "two" => 2 }
                  )
                end
              end
            end

            it "overwrites duplicated namespace and action with custom from context" do
              current_transaction = http_request_transaction
              current_transaction.set_namespace "custom"
              current_transaction.set_action "CustomAction"

              with_rails_error_reporter do
                with_current_transaction current_transaction do
                  given_context = {
                    :appsignal => { :namespace => "context", :action => "ContextAction" }
                  }
                  Rails.error.handle(:context => given_context) { raise ExampleStandardError }

                  transaction = last_transaction
                  expect(transaction).to have_namespace("context")
                  expect(transaction).to have_action("ContextAction")
                end
              end
            end
          end

          context "when no transaction is active" do
            class ExampleRailsRequestMock
              def path
                "path"
              end

              def method
                "GET"
              end

              def filtered_parameters
                { :user_id => 123, :password => "[FILTERED]" }
              end
            end

            class ExampleRailsControllerMock
              def action_name
                "index"
              end

              def request
                @request ||= ExampleRailsRequestMock.new
              end
            end

            class ExampleRailsJobMock
            end

            class ExampleRailsMailerMock < ActionMailer::MailDeliveryJob
              def arguments
                ["ExampleRailsMailerMock", "send_mail"]
              end
            end

            before do
              clear_current_transaction!
            end

            it "fetches the action, path and method from the controller in the context" do
              # The controller key is set by Rails when raised in a controller
              given_context = { :controller => ExampleRailsControllerMock.new }
              with_rails_error_reporter do
                Rails.error.handle(:context => given_context) { raise ExampleStandardError }
              end

              transaction = last_transaction
              expect(transaction).to have_action("ExampleRailsControllerMock#index")
              expect(transaction).to include_metadata("path" => "path", "method" => "GET")
              expect(transaction).to include_params("user_id" => 123,
                "password" => "[FILTERED]")
            end

            it "sets no action if no execution context is present" do
              # The controller key is set by Rails when raised in a controller
              with_rails_error_reporter do
                Rails.error.handle { raise ExampleStandardError }
              end

              expect(last_transaction).to_not have_action
            end
          end

          it "sets the error context as tags" do
            given_context = {
              :controller => ExampleRailsControllerMock.new, # Not set as tag
              :job => ExampleRailsJobMock.new, # Not set as tag
              :appsignal => { :something => "not used" }, # Not set as tag
              :tag1 => "value1",
              :tag2 => "value2"
            }
            with_rails_error_reporter do
              Rails.error.handle(:context => given_context) { raise ExampleStandardError }
            end

            expect(last_transaction).to include_tags(
              "tag1" => "value1",
              "tag2" => "value2",
              "severity" => "warning"
            )
          end
        end
      end
    end
  end
end
