if DependencyHelper.rails_present?
  require "action_mailer"

  describe Appsignal::Integrations::Railtie do
    include RailsHelper

    after { clear_rails_error_reporter! }

    context "after initializing the app" do
      it "should call initialize_appsignal" do
        expect(Appsignal::Integrations::Railtie).to receive(:initialize_appsignal)

        MyApp::Application.config.root = project_fixture_path
        MyApp::Application.initialize!
      end
    end

    describe "#initialize_appsignal" do
      let(:app) { MyApp::Application.new }

      describe ".internal_logger" do
        before  { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        subject { Appsignal.internal_logger }

        it { is_expected.to be_a Logger }
      end

      describe ".config" do
        let(:config) { Appsignal.config }

        describe "basic configuration" do
          before { Appsignal::Integrations::Railtie.initialize_appsignal(app) }

          it { expect(config).to be_a(Appsignal::Config) }

          it "sets the root_path" do
            expect(config.root_path).to eq Pathname.new(project_fixture_path)
          end

          it "sets the detected environment" do
            expect(config.env).to eq "test"
          end

          it "loads the app name" do
            expect(config[:name]).to eq "TestApp"
          end

          it "sets the log_path based on the root_path" do
            expect(config[:log_path]).to eq Pathname.new(File.join(project_fixture_path, "log"))
          end
        end

        context "with APPSIGNAL_APP_ENV ENV var set" do
          before do
            ENV["APPSIGNAL_APP_ENV"] = "env_test"
            Appsignal::Integrations::Railtie.initialize_appsignal(app)
          end

          it "uses the environment variable value as the environment" do
            expect(config.env).to eq "env_test"
          end
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
                Appsignal::Integrations::Railtie.initialize_appsignal(app)

                expect(error_reporter.subscribers)
                  .to eq([Appsignal::Integrations::RailsErrorReporterSubscriber])
              end
            end

            context "when enable_rails_error_reporter is disabled" do
              it "does not subscribe to the error reporter" do
                ENV["APPSIGNAL_ENABLE_RAILS_ERROR_REPORTER"] = "false"
                Appsignal::Integrations::Railtie.initialize_appsignal(app)

                expect(error_reporter.subscribers)
                  .to_not eq([Appsignal::Integrations::RailsErrorReporterSubscriber])
              end
            end
          end
        else
          context "when Rails does not listen to `error`" do
            it "does not error trying to subscribe to the error reporter" do
              Appsignal::Integrations::Railtie.initialize_appsignal(app)
            end
          end
        end
      end

      describe ".initial_config" do
        before { Appsignal::Integrations::Railtie.initialize_appsignal(app) }
        let(:config) { Appsignal.config.initial_config }

        it "returns the initial config" do
          expect(config[:name]).to eq "MyApp"
        end
      end

      describe "Rails listener middleware" do
        it "adds the Rails listener middleware" do
          expect(app.middleware).to receive(:insert_after).with(
            ActionDispatch::DebugExceptions,
            Appsignal::Rack::RailsInstrumentation
          )
          Appsignal::Integrations::Railtie.initialize_appsignal(app)
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
          end

          context "when error is handled (not reraised)" do
            context "when a transaction is active" do
              it "duplicates the transaction namespace, action and tags" do
                current_transaction = http_request_transaction
                current_transaction.set_namespace "custom"
                current_transaction.set_action "CustomAction"
                current_transaction.set_tags(
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
                current_transaction.set_tags(:tag1 => "duplicated value")

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
                expect(transaction).to include_params("user_id" => 123, "password" => "[FILTERED]")
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
end
