require "appsignal/cli"

describe Appsignal::CLI::Install do
  include CLIHelpers

  let(:out_stream) { StringIO.new }
  let(:output) { out_stream.string }
  let(:push_api_key) { "my_key" }
  let(:config) { Appsignal::Config.new(tmp_dir, "") }
  let(:config_file_path) { File.join(tmp_dir, "config", "appsignal.yml") }
  let(:config_file) { File.read(config_file_path) }
  before do
    stub_api_validation_request
    # Stub calls to speed up tests
    allow(described_class).to receive(:sleep)
    allow(described_class).to receive(:press_any_key)
    allow(Appsignal::Demo).to receive(:transmit).and_return(true)
  end
  around do |example|
    original_stdin = $stdin
    $stdin = StringIO.new
    capture_stdout(out_stream) { example.run }
    $stdin = original_stdin
  end

  define :include_complete_install do
    match do |actual|
      actual.include?("AppSignal installation complete")
    end
  end

  define :include_env_push_api_key do |key|
    match do |actual|
      actual.include?("export APPSIGNAL_PUSH_API_KEY=#{key}")
    end
  end
  define :include_env_app_name do |name|
    match do |actual|
      actual.include?("export APPSIGNAL_APP_NAME=#{name}")
    end
  end

  define :configure_app_name do |name|
    match do |file_contents|
      file_contents =~ /^  name: "#{name}"/
    end
  end
  define :configure_push_api_key do |key|
    match do |file_contents|
      file_contents =~ /^  push_api_key: "#{key}"/
    end
  end
  define :configure_environment do |env|
    match do |file_contents|
      file_contents =~ /^#{env}:$/
    end
  end
  define :include_file_config do
    match do |log|
      log.include?("Config file written to config/appsignal.yml")
    end
  end

  define :include_demo_transmission do
    match do |log|
      log.include?("Sending example data to AppSignal") &&
        log.include?("Example data sent!")
    end
  end

  def stub_api_validation_request
    config[:push_api_key] = push_api_key
    stub_api_request config, "auth"
  end

  alias_method :enter_app_name, :set_input

  def choose_config_file
    set_input "1"
  end

  def choose_environment_config
    set_input "2"
  end

  def run
    Dir.chdir tmp_dir do
      prepare_input
      run_cli(["install", push_api_key])
    end
  end

  shared_examples "push_api_key validation" do
    context "without key" do
      let(:push_api_key) {}

      it "does not install" do
        run

        expect(output).to include "Problem encountered:",
          "No push API key entered"
      end
    end

    context "with key" do
      let(:push_api_key) { "my_key" }

      context "when the key is valid" do
        before { stub_api_validation_request.to_return(:status => 200) }

        it "continues with the installer" do
          enter_app_name "Test App"
          choose_environment_config
          run

          expect(output).to include("Validating API key...", "API key valid")
        end
      end

      context "when the key is invalid" do
        before { stub_api_validation_request.to_return(:status => 402) }

        it "prints an error" do
          run
          expect(output).to include "API key 'my_key' is not valid"
        end
      end

      context "when there is an error validating" do
        before do
          expect(Appsignal::AuthCheck).to receive(:new).and_raise(StandardError)
        end

        it "prints an error" do
          run
          expect(output).to include "There was an error validating your API key"
        end
      end
    end
  end

  shared_examples "requires an application name" do
    before do
      enter_app_name ""
      enter_app_name "Test app"
      choose_environment_config
      run
    end

    it "requires an application name" do
      expect(output.scan(/Enter application name:/).length).to eq(2)
    end
  end

  shared_examples "capistrano install" do
    let(:capfile) { File.join(tmp_dir, "Capfile") }
    before do
      FileUtils.mkdir_p(tmp_dir)

      enter_app_name "foo"
      set_input "n"
      choose_environment_config
    end
    after do
      FileUtils.rm_rf(tmp_dir)
      FileUtils.mkdir_p(tmp_dir)
    end

    context "without Capfile" do
      it "does nothing" do
        run

        expect(output).to_not include "Adding AppSignal integration to Capfile"
        expect(File.exist?(capfile)).to be_false
      end
    end

    context "with Capfile" do
      context "when already installed" do
        before { File.open(capfile, "w") { |f| f.write("require 'appsignal/capistrano'") } }

        it "does not add another require to Capfile" do
          run

          expect(output).to_not include "Adding AppSignal integration to Capfile"
          expect(File.read(capfile).scan(/appsignal/).count).to eq(1)
        end
      end

      context "when not installed" do
        before { FileUtils.touch(capfile) }

        it "adds a require to Capfile" do
          run

          expect(output).to include "Adding AppSignal integration to Capfile"
          expect(File.read(capfile)).to include "require 'appsignal/capistrano'"
        end
      end
    end
  end

  shared_examples "windows installation" do
    before do
      allow(Gem).to receive(:win_platform?).and_return(true)
      expect(Appsignal::Demo).to_not receive(:transmit)
      run
    end

    it "prints a warning for windows" do
      expect(output).to include("The AppSignal agent currently does not work on Windows")
      expect(output).to include("test/staging/production environment")
    end
  end

  shared_examples "demo data" do
    context "with demo data sent" do
      before do
        expect(Appsignal::Demo).to receive(:transmit).and_return(true)
        run
      end

      it "prints sending demo data" do
        expect(output).to include "Sending example data to AppSignal", "Example data sent!"
      end
    end

    context "without demo data being sent" do
      before do
        expect(Appsignal::Demo).to receive(:transmit).and_return(false)
        run
      end

      it "prints that it couldn't send the demo data" do
        expect(output).to include "Sending example data to AppSignal",
          "Couldn't start the AppSignal agent and send example data",
          "`appsignal diagnose`"
      end
    end
  end

  if rails_present?
    context "with rails" do
      let(:installation_instructions) { ["Installing for Ruby on Rails"] }
      let(:app_name) { "MyApp" }
      let(:config_dir) { File.join(tmp_dir, "config") }
      let(:environments_dir) { File.join(config_dir, "environments") }
      before do
        # Fake Rails directory
        FileUtils.mkdir_p(config_dir)
        FileUtils.mkdir_p(environments_dir)
        FileUtils.touch(File.join(config_dir, "application.rb"))
        FileUtils.touch(File.join(environments_dir, "development.rb"))
        FileUtils.touch(File.join(environments_dir, "staging.rb"))
        FileUtils.touch(File.join(environments_dir, "production.rb"))
        enter_app_name app_name
      end

      describe "environments" do
        before do
          File.delete(File.join(environments_dir, "development.rb"))
          File.delete(File.join(environments_dir, "staging.rb"))
          set_input "n"
          choose_config_file
        end

        it "only configures the available environments" do
          run

          expect(output).to include_file_config
          expect(config_file).to configure_app_name(app_name)
          expect(config_file).to configure_push_api_key(push_api_key)
          expect(config_file).to_not configure_environment("development")
          expect(config_file).to_not configure_environment("staging")
          expect(config_file).to configure_environment("production")

          expect(output).to include(*installation_instructions)
          expect(output).to include_complete_install
          expect(output).to include_demo_transmission
        end
      end

      context "without custom name" do
        before { set_input "n" }

        it_behaves_like "push_api_key validation"

        context "with configuration using environment variables" do
          before { choose_environment_config }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "prints environment variables" do
            run

            expect(output).to include_env_push_api_key(push_api_key)
            expect(output).to_not include_env_app_name
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end

        context "with configuration using a configuration file" do
          before { choose_config_file }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "writes configuration to file" do
            run

            expect(output).to include_file_config
            expect(config_file).to configure_app_name(app_name)
            expect(config_file).to configure_push_api_key(push_api_key)
            expect(config_file).to configure_environment("development")
            expect(config_file).to configure_environment("staging")
            expect(config_file).to configure_environment("production")
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end
      end

      context "with custom name" do
        let(:app_name) { "Custom name" }
        before { set_input "y" }

        it_behaves_like "push_api_key validation"

        it "requires the custom name" do
          enter_app_name ""
          enter_app_name app_name
          choose_environment_config
          run

          expect(output.scan(/Choose app's display name:/).length).to eq(2)
        end

        context "with configuration using environment variables" do
          before do
            enter_app_name app_name
            choose_environment_config
          end

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "prints environment variables" do
            run

            expect(output).to include_env_push_api_key(push_api_key)
            expect(output).to include_env_app_name(app_name)
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end

        context "with configuration using a configuration file" do
          before do
            enter_app_name app_name
            choose_config_file
          end

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "writes configuration to file" do
            run

            expect(output).to include_file_config
            expect(config_file).to configure_app_name(app_name)
            expect(config_file).to configure_push_api_key(push_api_key)
            expect(config_file).to configure_environment("development")
            expect(config_file).to configure_environment("staging")
            expect(config_file).to configure_environment("production")
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end
      end
    end
  end

  if sinatra_present? && !padrino_present? && !rails_present?
    context "with sinatra" do
      it_behaves_like "push_api_key validation"
      it_behaves_like "requires an application name"

      describe "sinatra specific tests" do
        let(:installation_instructions) do
          [
            "Installing for Sinatra",
            "Sinatra requires some manual configuration.",
            "require 'appsignal/integrations/sinatra'",
            "http://docs.appsignal.com/getting-started/supported-frameworks.html#sinatra"
          ]
        end
        let(:app_name) { "Test app" }
        before { enter_app_name app_name }

        describe "configuration with environment variables" do
          before { choose_environment_config }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "prints environment variables" do
            run

            expect(output).to include_env_push_api_key(push_api_key)
            expect(output).to include_env_app_name(app_name)
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end

        describe "configure with a configuration file" do
          before { choose_config_file }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "writes configuration to file" do
            run

            expect(output).to include_file_config
            expect(config_file).to configure_app_name(app_name)
            expect(config_file).to configure_push_api_key(push_api_key)
            expect(config_file).to configure_environment("development")
            expect(config_file).to configure_environment("staging")
            expect(config_file).to configure_environment("production")
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end
      end
    end
  end

  if padrino_present?
    context "with padrino" do
      it_behaves_like "push_api_key validation"
      it_behaves_like "requires an application name"

      describe "padrino specific tests" do
        let(:installation_instructions) do
          [
            "Installing for Padrino",
            "Padrino requires some manual configuration.",
            "http://docs.appsignal.com/getting-started/supported-frameworks.html#padrino"
          ]
        end
        let(:app_name) { "Test app" }
        before { enter_app_name app_name }

        describe "configuration with environment variables" do
          before { choose_environment_config }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "prints environment variables" do
            run

            expect(output).to include_env_push_api_key(push_api_key)
            expect(output).to include_env_app_name(app_name)
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end

        describe "configure with a configuration file" do
          before { choose_config_file }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "writes configuration to file" do
            run

            expect(output).to include_file_config
            expect(config_file).to configure_app_name(app_name)
            expect(config_file).to configure_push_api_key(push_api_key)
            expect(config_file).to configure_environment("development")
            expect(config_file).to configure_environment("staging")
            expect(config_file).to configure_environment("production")
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end
      end
    end
  end

  if grape_present?
    context "with grape" do
      it_behaves_like "push_api_key validation"
      it_behaves_like "requires an application name"

      describe "grape specific tests" do
        let(:installation_instructions) do
          [
            "Installing for Grape",
            "Manual Grape configuration needed",
            "http://docs.appsignal.com/getting-started/supported-frameworks.html#grape"
          ]
        end
        let(:app_name) { "Test app" }
        before { enter_app_name app_name }

        describe "configuration with environment variables" do
          before { choose_environment_config }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "prints environment variables" do
            run

            expect(output).to include_env_push_api_key(push_api_key)
            expect(output).to include_env_app_name(app_name)
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end

        describe "configure with a configuration file" do
          before { choose_config_file }

          it_behaves_like "windows installation"
          it_behaves_like "capistrano install"
          it_behaves_like "demo data"

          it "writes configuration to file" do
            run

            expect(output).to include_file_config
            expect(config_file).to configure_app_name(app_name)
            expect(config_file).to configure_push_api_key(push_api_key)
            expect(config_file).to configure_environment("development")
            expect(config_file).to configure_environment("staging")
            expect(config_file).to configure_environment("production")
          end

          it "completes the installation" do
            run

            expect(output).to include(*installation_instructions)
            expect(output).to include_complete_install
          end
        end
      end
    end
  end

  if !rails_present? && !sinatra_present? && !padrino_present? && !grape_present?
    context "with unknown framework" do
      let(:push_api_key) { "my_key" }

      it_behaves_like "push_api_key validation"

      it "prints a message about unknown framework" do
        run

        expect(output).to include "We could not detect which framework you are using."
        expect(output).to_not include_env_push_api_key
        expect(output).to_not include_env_app_name
        expect(File.exist?(config_file_path)).to be_false
      end
    end
  end
end
