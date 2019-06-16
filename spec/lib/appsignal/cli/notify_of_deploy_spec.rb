require "appsignal/cli"

describe Appsignal::CLI::NotifyOfDeploy do
  include CLIHelpers

  let(:out_stream) { std_stream }
  let(:output) { out_stream.read }

  define :include_deploy_notification do
    match do |log|
      log.include?("Notifying AppSignal of deploy with: ") &&
        log.include?("AppSignal has been notified of this deploy!")
    end
  end
  define :include_deploy_notification_with do |options|
    match do |log|
      return false unless options
      values = "revision: #{options[:revision]}, user: #{options[:user]}"
      log.include?("Notifying AppSignal of deploy with: #{values}") &&
        log.include?("AppSignal has been notified of this deploy!")
    end
  end
  define :include_config_error do
    match do |log|
      log.include? "Error: No valid config found."
    end
  end
  define :include_missing_options do |options|
    match do |log|
      log.include? "Error: Missing options: #{options.join(", ")}"
    end
  end

  def run
    capture_stdout(out_stream) do
      run_cli("notify_of_deploy", options)
    end
  end

  context "without config" do
    let(:config) { Appsignal::Config.new(tmp_dir, "production") }
    let(:options) { {} }
    around do |example|
      Dir.chdir tmp_dir do
        example.run
      end
    end

    it "prints a config error" do
      expect { run }.to raise_error(SystemExit)
      expect(output).to include_config_error
      expect(output).to_not include_deploy_notification
    end
  end

  context "with config" do
    let(:config) { project_fixture_config }
    before do
      config[:name] = options[:name] if options[:name]
      stub_api_request config, "markers", :revision => options[:revision],
        :user => options[:user]
    end
    around do |example|
      Dir.chdir project_fixture_path do
        example.run
      end
    end

    context "without environment" do
      let(:options) { { :environment => "", :revision => "foo", :user => "thijs" } }
      before do
        # Makes the config "active"
        ENV["APPSIGNAL_PUSH_API_KEY"] = "foo"
      end

      it "requires environment option" do
        expect { run }.to raise_error(SystemExit)
        expect(output).to include_missing_options(%w[environment])
        expect(output).to_not include_deploy_notification
      end
    end

    context "without known environment" do
      let(:options) { { :environment => "foo" } }

      it "prints a config error" do
        expect { run }.to raise_error(SystemExit)
        expect(output).to include_config_error
        expect(output).to_not include_missing_options([])
        expect(output).to_not include_deploy_notification
      end
    end

    context "with known environment" do
      context "without required options" do
        let(:options) { { :environment => "production" } }

        it "prints a missing required options error" do
          expect { run }.to raise_error(SystemExit)
          expect(output).to_not include_config_error
          expect(output).to include_missing_options(%w[revision user])
          expect(output).to_not include_deploy_notification
        end

        context "with empty required option" do
          let(:options) { { :environment => "production", :revision => "foo", :user => "" } }

          it "prints a missing required option error" do
            expect { run }.to raise_error(SystemExit)
            expect(output).to_not include_config_error
            expect(output).to include_missing_options(%w[user])
            expect(output).to_not include_deploy_notification
          end
        end
      end

      context "with required options" do
        let(:options) { { :environment => "production", :revision => "aaaaa", :user => "thijs" } }
        let(:log_stream) { std_stream }
        let(:log) { log_contents(log_stream) }
        before { Appsignal.logger = test_logger(log_stream) }

        it "notifies of a deploy" do
          run
          expect(output).to_not include_config_error
          expect(output).to_not include_missing_options([])
          expect(output).to include_deploy_notification_with(options)
        end

        it "prints a deprecation message" do
          run
          deprecation_message = "This command (appsignal notify_of_deploy) has been deprecated"
          expect(output).to include("appsignal WARNING: #{deprecation_message}")
          expect(log).to contains_log :warn, deprecation_message
        end

        context "with no app name configured" do
          before { ENV["APPSIGNAL_APP_NAME"] = "" }

          context "without name option" do
            let(:options) { { :environment => "production", :revision => "aaaaa", :user => "thijs" } }

            it "requires name option" do
              expect { run }.to raise_error(SystemExit)
              expect(output).to_not include_config_error
              expect(output).to include_missing_options(%w[name])
              expect(output).to_not include_deploy_notification
            end
          end

          context "with name option" do
            let(:options) { { :environment => "production", :revision => "aaaaa", :user => "thijs", :name => "foo" } }

            it "notifies of a deploy with a custom name" do
              run
              expect(output).to_not include_config_error
              expect(output).to_not include_missing_options([])
              expect(output).to include_deploy_notification_with(options)
            end
          end
        end

        context "with name option" do
          let(:options) do
            { :environment => "production", :revision => "aaaaa", :user => "thijs", :name => "foo" }
          end

          it "notifies of a deploy with a custom name" do
            run
            expect(output).to_not include_config_error
            expect(output).to_not include_missing_options([])
            expect(output).to include_deploy_notification_with(options)
          end
        end
      end
    end
  end
end
