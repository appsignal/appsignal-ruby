require "bundler/cli"
require "bundler/cli/common"
require "appsignal/cli"

describe Appsignal::CLI::Diagnose, :api_stub => true, :send_report => :yes_cli_input,
  :color => false do
  include CLIHelpers

  class DiagnosticsReportEndpoint
    class << self
      attr_reader :received_report

      def clear_report!
        @received_report = nil
      end

      def call(env)
        @received_report = JSON.parse(env["rack.input"].read)["diagnose"]
        [200, {}, [JSON.generate(:token => "my_support_token")]]
      end
    end
  end

  describe ".run" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:config) { project_fixture_config }
    let(:cli_class) { described_class }
    let(:options) { { :environment => config.env } }
    let(:gem_path) { Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip }
    let(:received_report) { DiagnosticsReportEndpoint.received_report }
    let(:process_user) { Etc.getpwuid(Process.uid).name }
    let(:process_group) { Etc.getgrgid(Process.gid).name }
    before(:context) { Appsignal.stop }
    before do
      # Clear previous reports
      DiagnosticsReportEndpoint.clear_report!
      if cli_class.instance_variable_defined? :@data
        # Because this is saved on the class rather than an instance of the
        # class we need to clear it like this in case a certain test doesn't
        # generate a report.
        cli_class.send :remove_instance_variable, :@data
      end

      if DependencyHelper.rails_present?
        allow(Rails).to receive(:root).and_return(Pathname.new(config.root_path))
      end
    end
    around do |example|
      original_stdin = $stdin
      $stdin = StringIO.new
      example.run
      $stdin = original_stdin
    end
    before :api_stub => true do
      stub_api_request config, "auth"
    end
    before(:color => false) { options["no-color"] = nil }
    before(:color => true) { options["color"] = nil }
    before(:send_report => :yes_cli_input) do
      accept_prompt_to_send_diagnostics_report
      capture_diagnatics_report_request
    end
    before(:send_report => :no_cli_input) { dont_accept_prompt_to_send_diagnostics_report }
    before(:send_report => :yes_cli_option) do
      options["send-report"] = nil
      capture_diagnatics_report_request
    end
    before(:send_report => :no_cli_option) { options["no-send-report"] = nil }
    after { Appsignal.config = nil }

    def capture_diagnatics_report_request
      stub_diagnostics_report_request.to_rack(DiagnosticsReportEndpoint)
    end

    def run
      run_within_dir project_fixture_path
    end

    def run_within_dir(chdir)
      prepare_cli_input
      Dir.chdir chdir do
        capture_stdout(out_stream) { run_cli("diagnose", options) }
      end
    end

    def stub_diagnostics_report_request
      stub_request(:post, "https://appsignal.com/diag").with(
        :query => {
          :api_key => config[:push_api_key],
          :environment => config.env,
          :gem_version => Appsignal::VERSION,
          :hostname => config[:hostname],
          :name => config[:name]
        },
        :headers => { "Content-Type" => "application/json; charset=UTF-8" }
      )
    end

    def accept_prompt_to_send_diagnostics_report
      add_cli_input "y"
    end

    def dont_accept_prompt_to_send_diagnostics_report
      add_cli_input "n"
    end

    it "outputs header and support text" do
      run
      expect(output).to include \
        "AppSignal diagnose",
        "https://docs.appsignal.com/",
        "support@appsignal.com"
    end

    it "logs to the log file" do
      run
      log_contents = File.read(config.log_file_path)
      expect(log_contents).to contains_log :info, "Starting AppSignal diagnose"
    end

    describe "report" do
      context "when user wants to send report" do
        it "sends report" do
          run
          expect(output).to include "Diagnostics report",
            "Send diagnostics report to AppSignal? (Y/n): "
        end

        it "outputs the support token from the server" do
          run
          expect(output).to include "Your support token: my_support_token"
          expect(output).to include "View this report:   https://appsignal.com/diagnose/my_support_token"
        end

        context "when server response is invalid" do
          before do
            stub_diagnostics_report_request
              .to_return(:status => 200, :body => %({ foo: "Invalid json", a: }))
            run
          end

          it "outputs the server response in full" do
            expect(output).to include "Error: Couldn't decode server response.",
              %({ foo: "Invalid json", a: })
          end
        end

        context "when server returns an error" do
          before do
            stub_diagnostics_report_request
              .to_return(:status => 500, :body => "report: server error")
            run
          end

          it "outputs the server response in full" do
            expect(output).to include "report: server error"
          end
        end
      end

      context "when user uses the --send-report option", :send_report => :yes_cli_option do
        it "sends the report without prompting" do
          run
          expect(output).to include "Diagnostics report",
            "Confirmed sending report using --send-report option.",
            "Transmitting diagnostics report"
        end
      end

      context "when user uses the --no-send-report option", :send_report => :no_cli_option do
        it "does not send the report" do
          run
          expect(output).to include "Diagnostics report",
            "Not sending report. (Specified with the --no-send-report option.)",
            "Not sending diagnostics information to AppSignal."
        end
      end

      context "when user doesn't want to send report", :send_report => :no_cli_input do
        it "does not send report" do
          run
          expect(output).to include "Diagnostics report",
            "Send diagnostics report to AppSignal? (Y/n): ",
            "Not sending diagnostics information to AppSignal."
        end
      end
    end

    describe "agent information" do
      before { run }

      it "outputs version numbers" do
        expect(output).to include \
          "Gem version: \"#{Appsignal::VERSION}\"",
          "Agent version: \"#{Appsignal::Extension.agent_version}\""
      end

      it "transmits version numbers in report" do
        expect(received_report).to include(
          "library" => {
            "language" => "ruby",
            "package_version" => Appsignal::VERSION,
            "agent_version" => Appsignal::Extension.agent_version,
            "extension_loaded" => true
          }
        )
      end

      context "with extension" do
        before { run }

        it "outputs extension is loaded" do
          expect(output).to include "Extension loaded: true"
        end

        it "transmits extension_loaded: true in report" do
          expect(received_report["library"]["extension_loaded"]).to eq(true)
        end
      end

      context "without extension" do
        before do
          # When the extension isn't loaded the Appsignal.start operation exits
          # early and doesn't load the configuration.
          # Happens when the extension wasn't installed properly.
          Appsignal.extension_loaded = false
          run
        end
        after { Appsignal.extension_loaded = true }

        it "outputs extension is not loaded" do
          expect(output).to include "Extension loaded: false"
          expect(output).to include "Extension is not loaded. No agent report created."
        end

        context "with color", :color => true do
          it "outputs extension is not loaded in color" do
            expect(output).to have_colorized_text :red,
              "  Extension is not loaded. No agent report created."
          end
        end

        it "transmits extension_loaded: false in report" do
          expect(received_report["library"]["extension_loaded"]).to eq(false)
        end
      end
    end

    describe "installation report" do
      let(:rbconfig) { RbConfig::CONFIG }

      it "adds the installation report to the diagnostics report" do
        run
        jruby = Appsignal::System.jruby?
        language = {
          "name" => "ruby",
          "version" => "#{RUBY_VERSION}#{"-p#{rbconfig["PATCHLEVEL"]}" unless jruby}",
          "implementation" => jruby ? "jruby" : "ruby"
        }
        language["implementation_version"] = JRUBY_VERSION if jruby
        expect(received_report["installation"]).to match(
          "result" => {
            "status" => "success"
          },
          "language" => language,
          "download" => {
            "download_url" => kind_of(String),
            "checksum" => "verified",
            "http_proxy" => nil
          },
          "build" => {
            "time" => kind_of(String),
            "package_path" => File.expand_path("../../../..", __dir__),
            "architecture" => Appsignal::System.agent_architecture,
            "target" => Appsignal::System.agent_platform,
            "musl_override" => false,
            "linux_arm_override" => false,
            "library_type" => jruby ? "dynamic" : "static",
            "source" => "remote",
            "dependencies" => kind_of(Hash),
            "flags" => kind_of(Hash),
            "agent_version" => Appsignal::Extension.agent_version
          },
          "host" => {
            "root_user" => false,
            "dependencies" => kind_of(Hash)
          }
        )
      end

      it "prints the extension installation report" do
        run
        jruby = Appsignal::System.jruby?
        expect(output).to include(
          "Extension installation report",
          "Installation result",
          "  Status: success",
          "Language details",
          "  Implementation: \"#{jruby ? "jruby" : "ruby"}\"",
          "  Ruby version: \"#{"#{rbconfig["RUBY_PROGRAM_VERSION"]}-p#{rbconfig["PATCHLEVEL"]}"}\"",
          "Download details",
          "  Download URL: \"https://",
          "  Checksum: \"verified\"",
          "Build details",
          "  Install time: \"20",
          "  Architecture: \"#{Appsignal::System.agent_architecture}\"",
          "  Target: \"#{Appsignal::System.agent_platform}\"",
          "  Musl override: false",
          "  Linux ARM override: false",
          "  Library type: \"#{jruby ? "dynamic" : "static"}\"",
          "  Dependencies: {",
          "  Flags: {",
          "Host details",
          "  Root user: false",
          "  Dependencies: {"
        )
      end

      context "with error in install report" do
        let(:error) { RuntimeError.new("some error") }
        before do
          allow(File).to receive(:read).and_call_original
          expect(File).to receive(:read)
            .with(File.expand_path("../../../../ext/install.report", __dir__))
            .and_return(
              JSON.generate(
                "result" => {
                  "status" => "error",
                  "error" => "RuntimeError: some error",
                  "backtrace" => error.backtrace
                }
              )
            )
        end

        it "sends an error" do
          run
          expect(received_report["installation"]).to match(
            "result" => {
              "status" => "error",
              "error" => "RuntimeError: some error",
              "backtrace" => error.backtrace
            }
          )
        end

        it "prints the error" do
          run

          expect(output).to include(
            "Extension installation report",
            "Installation result",
            "Status: error\n    Error: RuntimeError: some error"
          )
          expect(output).to_not include("Raw report:")
        end
      end

      context "without install report" do
        let(:error) { RuntimeError.new("foo") }
        before do
          allow(File).to receive(:read).and_call_original
          expect(File).to receive(:read)
            .with(File.expand_path("../../../../ext/install.report", __dir__))
            .and_raise(error)
        end

        it "sends an error" do
          run
          expect(received_report["installation"]).to match(
            "parsing_error" => {
              "error" => "RuntimeError: foo",
              "backtrace" => error.backtrace
            }
          )
        end

        it "prints the error" do
          run
          expect(output).to include(
            "Extension installation report",
            "  Error found while parsing the report.",
            "  Error: RuntimeError: foo"
          )
          expect(output).to_not include("Raw report:")
        end
      end

      context "when report is invalid JSON" do
        let(:raw_report) { "{}-" }
        before do
          allow(File).to receive(:read).and_call_original
          expect(File).to receive(:read)
            .with(File.expand_path("../../../../ext/install.report", __dir__))
            .and_return(raw_report)
        end

        it "sends an error" do
          run
          expect(received_report["installation"]).to match(
            "parsing_error" => {
              "error" => kind_of(String),
              "backtrace" => kind_of(Array),
              "raw" => raw_report
            }
          )
        end

        it "prints the error" do
          run
          expect(output).to include(
            "Extension installation report",
            "  Error found while parsing the report.",
            "  Error: ",
            "  Raw report:\n#{raw_report}"
          )
        end
      end
    end

    describe "agent diagnostics" do
      let(:working_directory_stat) { File.stat("/tmp/appsignal") }

      it "starts the agent in diagnose mode and outputs the report" do
        run
        working_directory_stat = File.stat("/tmp/appsignal")
        expect_valid_agent_diagnostics_report(output, working_directory_stat)
      end

      it "adds the agent diagnostics to the report" do
        run
        expect(received_report["agent"]).to eq(
          "extension" => {
            "config" => { "valid" => { "result" => true } }
          },
          "agent" => {
            "boot" => { "started" => { "result" => true } },
            "host" => {
              "uid" => { "result" => Process.uid },
              "gid" => { "result" => Process.gid },
              "running_in_container" => { "result" => Appsignal::Extension.running_in_container? }
            },
            "config" => { "valid" => { "result" => true } },
            "logger" => { "started" => { "result" => true } },
            "working_directory_stat" => {
              "uid" => { "result" => working_directory_stat.uid },
              "gid" => { "result" => working_directory_stat.gid },
              "mode" => { "result" => working_directory_stat.mode }
            },
            "lock_path" => { "created" => { "result" => true } }
          }
        )
      end

      context "when user config has active: false" do
        before do
          # ENV is leading so easiest to set in test to force user config with active: false
          ENV["APPSIGNAL_ACTIVE"] = "false"
        end

        it "force starts the agent in diagnose mode and outputs a log" do
          run
          expect(output).to include("active: false")
          expect_valid_agent_diagnostics_report(output, working_directory_stat)
        end
      end

      context "when the extension returns invalid JSON" do
        before do
          expect(Appsignal::Extension).to receive(:diagnose).and_return("invalid agent\njson")
          run
        end

        it "prints a JSON parse error and prints the returned value" do
          expect(output).to include \
            "Agent diagnostics",
            "  Error while parsing agent diagnostics report:",
            "    Output: invalid agent\njson"
          expect(output).to match(/Error:( \d+:)? unexpected token at 'invalid agent\njson'/)
        end

        it "adds the output to the report" do
          expect(received_report["agent"]["error"])
            .to match(/unexpected token at 'invalid agent\njson'/)
          expect(received_report["agent"]["output"]).to eq(["invalid agent", "json"])
        end
      end

      context "when the extension is not loaded" do
        before do
          DiagnosticsReportEndpoint.clear_report!
          expect(Appsignal).to receive(:extension_loaded?).and_return(false)
          run
        end

        it "prints a warning" do
          expect(output).to include \
            "Agent diagnostics",
            "  Extension is not loaded. No agent report created."
        end

        it "adds the output to the report" do
          expect(received_report["agent"]).to be_nil
        end
      end

      context "when the report contains an error" do
        let(:agent_report) do
          { "error" => "fatal error" }
        end
        before do
          expect(Appsignal::Extension).to receive(:diagnose).and_return(JSON.generate(agent_report))
          run
        end

        it "prints an error for the entire report" do
          expect(output).to include "Agent diagnostics\n  Error: fatal error"
        end

        it "adds the error to the report" do
          expect(received_report["agent"]).to eq(agent_report)
        end
      end

      context "when the report is incomplete (agent failed to start)" do
        let(:agent_report) do
          {
            "extension" => {
              "config" => { "valid" => { "result" => false } }
            }
            # missing agent section
          }
        end
        before do
          expect(Appsignal::Extension).to receive(:diagnose).and_return(JSON.generate(agent_report))
          run
        end

        it "prints the tests, but shows a dash `-` for missed results" do
          expect(output).to include \
            "Agent diagnostics",
            "  Extension tests\n    Configuration: invalid",
            "  Agent tests",
            "    Started: -",
            "    Configuration: -",
            "    Logger: -",
            "    Lock path: -"
        end

        it "adds the output to the report" do
          expect(received_report["agent"]).to eq(agent_report)
        end
      end

      context "when a test contains an error" do
        let(:agent_report) do
          {
            "extension" => {
              "config" => { "valid" => { "result" => true } }
            },
            "agent" => {
              "boot" => {
                "started" => { "result" => false, "error" => "some-error" }
              }
            }
          }
        end
        before do
          expect(Appsignal::Extension).to receive(:diagnose).and_return(JSON.generate(agent_report))
          run
        end

        it "prints the error and output" do
          expect(output).to include \
            "Agent diagnostics",
            "  Extension tests\n    Configuration: valid",
            "  Agent tests\n    Started: not started\n      Error: some-error"
        end

        it "adds the agent report to the diagnostics report" do
          expect(received_report["agent"]).to eq(agent_report)
        end
      end

      context "when a test contains command output" do
        let(:agent_report) do
          {
            "extension" => {
              "config" => { "valid" => { "result" => true } }
            },
            "agent" => {
              "config" => { "valid" => { "result" => false, "output" => "some output" } }
            }
          }
        end

        it "prints the command output" do
          expect(Appsignal::Extension).to receive(:diagnose).and_return(JSON.generate(agent_report))
          run
          expect(output).to include \
            "Agent diagnostics",
            "  Extension tests\n    Configuration: valid",
            "    Configuration: invalid\n      Output: some output"
        end
      end
    end

    describe "host information" do
      let(:rbconfig) { RbConfig::CONFIG }
      let(:language_version) { "#{rbconfig["RUBY_PROGRAM_VERSION"]}-p#{rbconfig["PATCHLEVEL"]}" }

      it "outputs host information" do
        run
        expect(output).to include \
          "Host information",
          "Architecture: \"#{rbconfig["host_cpu"]}\"",
          "Operating System: \"#{rbconfig["host_os"]}\"",
          "Ruby version: \"#{language_version}\""
      end

      context "when on Microsoft Windows" do
        before do
          expect(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mingw32")
          expect(RbConfig::CONFIG).to receive(:[]).at_least(:once).and_call_original
          expect(Gem).to receive(:win_platform?).and_return(true)
          run
        end

        it "adds the arch to the report" do
          expect(received_report["host"]["os"]).to eq("mingw32")
        end

        it "prints warning that Microsoft Windows is not supported" do
          expect(output).to match(/Operating System: .+ \(Microsoft Windows is not supported\.\)/)
        end
      end

      it "transmits host information in report" do
        run
        host_report = received_report["host"]
        host_report.delete("running_in_container") # Tested elsewhere
        distribution_file = "/etc/os-release"
        os_distribution = File.exist?(distribution_file) ? File.read(distribution_file) : ""
        expect(host_report).to eq(
          "architecture" => rbconfig["host_cpu"],
          "os" => rbconfig["host_os"],
          "os_distribution" => os_distribution,
          "language_version" => language_version,
          "heroku" => false,
          "root" => false
        )
      end

      describe "root user detection" do
        context "when not root user" do
          it "outputs false" do
            run
            expect(output).to include "Root user: false"
          end

          it "transmits root: false in report" do
            run
            expect(received_report["host"]["root"]).to eq(false)
          end
        end

        context "when root user" do
          before do
            allow(Process).to receive(:uid).and_return(0)
            run
          end

          it "outputs true, with warning" do
            expect(output).to include "Root user: true (not recommended)"
          end

          it "transmits root: true in report" do
            expect(received_report["host"]["root"]).to eq(true)
          end
        end
      end

      describe "Heroku detection" do
        context "when not on Heroku" do
          before { run }

          it "does not output Heroku detection" do
            expect(output).to_not include("Heroku:")
          end

          it "transmits heroku: false in report" do
            expect(received_report["host"]["heroku"]).to eq(false)
          end
        end

        context "when on Heroku" do
          before { recognize_as_heroku { run } }

          it "outputs Heroku detection" do
            expect(output).to include("Heroku: true")
          end

          it "transmits heroku: true in report" do
            expect(received_report["host"]["heroku"]).to eq(true)
          end
        end
      end

      describe "container detection" do
        context "when not in container" do
          before do
            allow(Appsignal::Extension).to receive(:running_in_container?).and_return(false)
            run
          end

          it "outputs: false" do
            expect(output).to include("Running in container: false")
          end

          it "transmits running_in_container: false in report" do
            expect(received_report["host"]["running_in_container"]).to eq(false)
          end
        end

        context "when in container" do
          before do
            allow(Appsignal::Extension).to receive(:running_in_container?).and_return(true)
            run
          end

          it "outputs: true" do
            expect(output).to include("Running in container: true")
          end

          it "transmits running_in_container: true in report" do
            expect(received_report["host"]["running_in_container"]).to eq(true)
          end
        end
      end
    end

    describe "configuration" do
      context "without environment" do
        let(:config) { project_fixture_config(nil) }
        let(:options) { {} }
        let(:warning_message) do
          "    Warning: No environment set, no config loaded!\n" \
            "    Please make sure appsignal diagnose is run within your\n" \
            "    project directory with an environment.\n" \
            "      appsignal diagnose --environment=production"
        end
        before do
          ENV.delete("RAILS_ENV") # From spec_helper
          ENV.delete("RACK_ENV")
          run_within_dir tmp_dir
        end

        it "outputs a warning that no config is loaded" do
          expect(output).to include "environment: \"\"\n#{warning_message}"
          expect(output).to_not have_color_markers
        end

        context "with color", :color => true do
          it "outputs a warning that no config is loaded in color" do
            expect(output).to include "environment: \"\"\n"
            expect(output).to have_colorized_text :red, warning_message
          end
        end

        it "outputs config defaults" do
          expect(output).to include("Configuration")
          expect_config_to_be_printed(Appsignal::Config::DEFAULT_CONFIG)
        end

        it "transmits validation in report" do
          default_config = hash_with_string_keys(Appsignal::Config::DEFAULT_CONFIG)
          expect(received_report["config"]).to eq(
            "options" => default_config.merge("env" => "", "send_session_data" => true),
            "sources" => {
              "default" => default_config,
              "system" => {},
              "initial" => { "env" => "" },
              "file" => {},
              "env" => {},
              "override" => { "send_session_data" => true }
            },
            "modifiers" => {
              "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR" => ""
            }
          )
        end
      end

      context "with configured environment" do
        describe "environment" do
          it "outputs environment" do
            run
            expect(output).to include(%(environment: "production"))
          end

          context "when the source is a single source" do
            before { run }

            it "outputs the label source after the value" do
              expect(output).to include(
                %(environment: "#{Appsignal.config.env}" (Loaded from: initial)\n)
              )
            end
          end

          context "when the source is the RACK_ENV env variable", :send_report => :no_cli_option do
            let(:config) { project_fixture_config("rack_env") }
            let(:options) { {} }
            before do
              ENV["RACK_ENV"] = "rack_env"
              run
            end
            after { ENV.delete("RACK_ENV") }

            it "outputs the RACK_ENV variable value" do
              expect(output).to include(
                %(environment: "rack_env" (Loaded from: initial)\n)
              )
            end
          end

          context "when the source is the RAILS_ENV env variable", :send_report => :no_cli_option do
            let(:config) { project_fixture_config("rails_env") }
            let(:options) { {} }
            before do
              ENV.delete("RACK_ENV")
              ENV["RAILS_ENV"] = "rails_env"
              run
            end
            after { ENV.delete("RAILS_ENV") }

            it "outputs the RAILS_ENV variable value" do
              expect(output).to include(
                %(environment: "rails_env" (Loaded from: initial)\n)
              )
            end
          end

          context "when the source is multiple sources" do
            let(:options) { { :environment => "development" } }
            before do
              ENV["APPSIGNAL_APP_ENV"] = "production"
              config.instance_variable_set(:@env, ENV.fetch("APPSIGNAL_APP_ENV", nil))
              stub_api_request(config, "auth").to_return(:status => 200)
              capture_diagnatics_report_request
              run
            end

            it "outputs a list of sources with their values" do
              expect(output).to include(
                "  environment: \"production\"\n" \
                  "    Sources:\n" \
                  "      initial: \"development\"\n" \
                  "      env:     \"production\"\n"
              )
            end
          end
        end

        it "outputs configuration" do
          run
          expect(output).to include("Configuration")
          expect_config_to_be_printed(Appsignal.config.config_hash)
        end

        describe "option sources" do
          context "when the source is a single source" do
            before { run }

            it "outputs the label source after the value" do
              expect(output).to include(
                %(push_api_key: "#{Appsignal.config[:push_api_key]}" (Loaded from: file)\n)
              )
            end

            context "when the source is only default" do
              it "does not print a source" do
                expect(output).to include("debug: #{Appsignal.config[:debug]}\n")
              end
            end
          end

          context "when the source is multiple sources" do
            before do
              ENV["APPSIGNAL_APP_NAME"] = "MyApp"
              config[:name] = ENV.fetch("APPSIGNAL_APP_NAME", nil)
              stub_api_request(config, "auth").to_return(:status => 200)
              capture_diagnatics_report_request
              run
            end

            if DependencyHelper.rails_present?
              it "outputs a list of sources with their values" do
                expect(output).to include(
                  "  name: \"MyApp\"\n" \
                    "    Sources:\n" \
                    "      initial: \"MyApp\"\n" \
                    "      file:    \"TestApp\"\n" \
                    "      env:     \"MyApp\"\n"
                )
              end
            else
              it "outputs a list of sources with their values" do
                expect(output).to include(
                  "  name: \"MyApp\"\n" \
                    "    Sources:\n" \
                    "      file: \"TestApp\"\n" \
                    "      env:  \"MyApp\"\n"
                )
              end
            end
          end
        end

        describe "modifiers" do
          before do
            ENV["APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR"] = "1"
            run
          end

          it "outputs config modifiers" do
            expect(output).to include(
              "Configuration modifiers\n" \
                "  APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR: \"1\""
            )
          end

          it "transmits config modifiers in report" do
            expect(received_report["config"]).to include(
              "modifiers" => {
                "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR" => "1"
              }
            )
          end
        end

        it "transmits config in report" do
          run
          additional_initial_config = {}
          if DependencyHelper.rails_present?
            additional_initial_config = {
              :name => "MyApp",
              :log_path => File.join(Rails.root, "log")
            }
          end
          final_config = { "env" => "production" }
            .merge(additional_initial_config)
            .merge(config.config_hash)
          expect(received_report["config"]).to match(
            "options" => hash_with_string_keys(final_config),
            "sources" => {
              "default" => hash_with_string_keys(Appsignal::Config::DEFAULT_CONFIG),
              "system" => {},
              "initial" => hash_with_string_keys(
                config.initial_config.merge(additional_initial_config)
              ),
              "file" => hash_with_string_keys(config.file_config),
              "env" => {},
              "override" => { "send_session_data" => true }
            },
            "modifiers" => {
              "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR" => ""
            }
          )
        end
      end

      context "with unconfigured environment" do
        let(:config) { project_fixture_config("foobar") }
        before { run_within_dir tmp_dir }

        it "outputs environment" do
          expect(output).to include(%(environment: "foobar"))
        end

        it "outputs config defaults" do
          expect(output).to include("Configuration")
          expect_config_to_be_printed(Appsignal::Config::DEFAULT_CONFIG)
        end

        it "transmits config in report" do
          expect(received_report["config"]).to match(
            "options" => hash_with_string_keys(config.config_hash).merge("env" => "foobar"),
            "sources" => {
              "default" => hash_with_string_keys(Appsignal::Config::DEFAULT_CONFIG),
              "system" => {},
              "initial" => hash_with_string_keys(config.initial_config),
              "file" => hash_with_string_keys(config.file_config),
              "env" => {},
              "override" => { "send_session_data" => true }
            },
            "modifiers" => {
              "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR" => ""
            }
          )
        end
      end

      def expect_config_to_be_printed(config)
        nil_options = config.select { |_, v| v.nil? }
        nil_options.each_key do |key|
          expect(output).to include(%(#{key}: nil))
        end
        string_options = config.select { |_, v| v.is_a?(String) }
        string_options.each do |key, value|
          expect(output).to include(%(#{key}: "#{value}"))
        end
        other_options = config.select do |k, _|
          !string_options.key?(k) && !nil_options.key?(k)
        end
        other_options.each do |key, value|
          expect(output).to include(%(#{key}: #{value}))
        end
      end
    end

    describe "API key validation", :api_stub => false do
      context "with valid key" do
        before do
          stub_api_request(config, "auth").to_return(:status => 200)
          run
        end

        it "outputs valid" do
          expect(output).to include "Validation",
            "Validating Push API key: valid"
        end

        context "with color", :color => true do
          it "outputs valid in color" do
            expect(output).to include "Validation",
              "Validating Push API key: #{colorize("valid", :green)}"
          end
        end

        it "transmits validation in report" do
          expect(received_report).to include(
            "validation" => {
              "push_api_key" => "valid"
            }
          )
        end
      end

      context "with invalid key" do
        before do
          stub_api_request(config, "auth").to_return(:status => 401)
          run
        end

        it "outputs invalid" do
          expect(output).to include "Validation",
            "Validating Push API key: invalid"
        end

        context "with color", :color => true do
          it "outputs invalid in color" do
            expect(output).to include "Validation",
              "Validating Push API key: #{colorize("invalid", :red)}"
          end
        end

        it "transmits validation in report" do
          expect(received_report).to include(
            "validation" => {
              "push_api_key" => "invalid"
            }
          )
        end
      end

      context "with invalid key" do
        before do
          stub_api_request(config, "auth").to_return(:status => 500)
          run
        end

        it "outputs failure with status code" do
          expect(output).to include "Validation",
            "Validating Push API key: Failed to validate: status 500\n" +
              %("Could not confirm authorization: 500")
        end

        context "with color", :color => true do
          it "outputs error in color" do
            expect(output).to include "Validation",
              "Validating Push API key: #{colorize(
                %(Failed to validate: status 500\n"Could not confirm authorization: 500"),
                :red
              )}"
          end
        end

        it "transmits validation in report" do
          expect(received_report).to include(
            "validation" => {
              "push_api_key" => "Failed to validate: status 500\n" +
              %("Could not confirm authorization: 500")
            }
          )
        end
      end
    end

    describe "paths" do
      let(:config) { Appsignal::Config.new(root_path, "production") }
      let(:root_path) { tmp_dir }
      let(:system_tmp_dir) { Appsignal::Config.system_tmp_dir }
      before do
        FileUtils.mkdir_p(root_path)
        FileUtils.mkdir_p(system_tmp_dir)
      end
      after { FileUtils.rm_rf([root_path, system_tmp_dir]) }

      describe "report" do
        it "adds paths to the report" do
          run_within_dir root_path
          expect(received_report["paths"].keys).to match_array(
            %w[
              package_install_path root_path working_dir log_dir_path
              ext/mkmf.log appsignal.log
            ]
          )
        end

        describe "working_dir" do
          before { run_within_dir root_path }

          it "outputs current path" do
            expect(output).to include %(Current working directory\n    Path: "#{tmp_dir}")
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["working_dir"]).to match(
              "path" => tmp_dir,
              "exists" => true,
              "type" => "directory",
              "mode" => kind_of(String),
              "writable" => boolean,
              "ownership" => {
                "uid" => kind_of(Integer),
                "user" => kind_of(String),
                "gid" => kind_of(Integer),
                "group" => kind_of(String)
              }
            )
          end
        end

        describe "root_path" do
          before { run_within_dir root_path }

          it "outputs root path" do
            expect(output).to include %(Root path\n    Path: "#{root_path}")
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["root_path"]).to match(
              "path" => root_path,
              "exists" => true,
              "type" => "directory",
              "mode" => kind_of(String),
              "writable" => boolean,
              "ownership" => {
                "uid" => kind_of(Integer),
                "user" => kind_of(String),
                "gid" => kind_of(Integer),
                "group" => kind_of(String)
              }
            )
          end
        end

        describe "package_install_path" do
          before { run_within_dir root_path }

          it "outputs gem install path" do
            expect(output).to match %(AppSignal gem path\n    Path: "#{gem_path}")
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["package_install_path"]).to match(
              "path" => gem_path,
              "exists" => true,
              "type" => "directory",
              "mode" => kind_of(String),
              "writable" => boolean,
              "ownership" => {
                "uid" => kind_of(Integer),
                "user" => kind_of(String),
                "gid" => kind_of(Integer),
                "group" => kind_of(String)
              }
            )
          end
        end

        describe "log_dir_path" do
          before { run_within_dir root_path }

          it "outputs log directory path" do
            expect(output).to match %(Log directory\n    Path: "#{system_tmp_dir}")
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["log_dir_path"]).to match(
              "path" => system_tmp_dir,
              "exists" => true,
              "type" => "directory",
              "mode" => kind_of(String),
              "writable" => boolean,
              "ownership" => {
                "uid" => kind_of(Integer),
                "user" => kind_of(String),
                "gid" => kind_of(Integer),
                "group" => kind_of(String)
              }
            )
          end
        end
      end

      context "when a directory does not exist" do
        let(:root_path) { tmp_dir }
        let(:execution_path) { File.join(tmp_dir, "not_existing_dir") }
        let(:config) do
          silence(:allowed => ["Push api key not set after loading config"]) do
            Appsignal::Config.new(execution_path, "production")
          end
        end
        before do
          allow(Dir).to receive(:pwd).and_return(execution_path)
          run_within_dir tmp_dir
        end

        it "outputs not existing path" do
          expect(output).to include %(Root path\n    Path: "#{execution_path}"\n    Exists?: false)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["root_path"]).to eq(
            "path" => execution_path,
            "exists" => false
          )
        end
      end

      context "when not writable" do
        let(:root_path) { File.join(tmp_dir, "not_writable_path") }
        before do
          FileUtils.chmod(0o555, root_path)
          run_within_dir root_path
        end

        it "outputs not writable root path" do
          expect(output).to include %(Root path\n    Path: "#{root_path}"\n    Writable?: false)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["root_path"]).to eq(
            "path" => root_path,
            "exists" => true,
            "type" => "directory",
            "mode" => "40555",
            "writable" => false,
            "ownership" => {
              "uid" => Process.uid,
              "user" => process_user,
              "gid" => Process.gid,
              "group" => process_group
            }
          )
        end
      end

      context "when writable" do
        let(:root_path) { File.join(tmp_dir, "writable_path") }
        before do
          FileUtils.chmod(0o755, root_path)
          run_within_dir root_path
        end

        it "outputs writable root path" do
          expect(output).to include %(Root path\n    Path: "#{root_path}"\n    Writable?: true)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["root_path"]).to eq(
            "path" => root_path,
            "exists" => true,
            "type" => "directory",
            "mode" => "40755",
            "writable" => true,
            "ownership" => {
              "uid" => Process.uid,
              "user" => process_user,
              "gid" => Process.gid,
              "group" => process_group
            }
          )
        end
      end

      describe "ownership" do
        context "when a directory is owned by the current user" do
          let(:root_path) { File.join(tmp_dir, "owned_path") }
          before { run_within_dir root_path }

          it "outputs ownership" do
            expect(output).to include \
              %(Root path\n    Path: "#{root_path}"\n    Writable?: true\n    ) \
                "Ownership?: true (file: #{process_user}:#{Process.uid}, " \
                "process: #{process_user}:#{Process.uid})"
          end

          it "transmits path data in report" do
            mode = ENV["RUNNING_IN_CI"] ? "40775" : "40755"
            expect(received_report["paths"]["root_path"]).to eq(
              "path" => root_path,
              "exists" => true,
              "type" => "directory",
              "mode" => mode,
              "writable" => true,
              "ownership" => {
                "uid" => Process.uid,
                "user" => process_user,
                "gid" => Process.gid,
                "group" => process_group
              }
            )
          end
        end

        context "when a directory is not owned by the current user" do
          let(:root_path) { File.join(tmp_dir, "not_owned_path") }
          before do
            stat = File.stat(root_path)
            allow(stat).to receive(:uid).and_return(0)
            allow(File).to receive(:stat).and_return(stat)
            run_within_dir root_path
          end

          it "outputs no ownership" do
            expect(output).to include \
              %(Root path\n    Path: "#{root_path}"\n    Writable?: true\n    ) \
                "Ownership?: false (file: root:0, process: #{process_user}:#{Process.uid})"
          end
        end
      end
    end

    describe "files" do
      shared_examples "diagnose file" do |shared_example_options|
        let(:parent_directory) { File.join(tmp_dir, "diagnose_files") }
        let(:file_path) { File.join(parent_directory, filename) }
        let(:path_key) { filename }
        before { FileUtils.mkdir_p File.dirname(file_path) }
        after { FileUtils.rm_rf parent_directory }

        context "when file exists" do
          let(:contents) do
            [].tap do |lines|
              (1..12).each do |i|
                lines << "log line #{i}"
              end
            end
          end
          before do
            File.open file_path, "a" do |f|
              contents.each do |line|
                f.puts line
              end
            end
            run
          end

          it "outputs file location and content" do
            expect(output).to include(
              %(Path: "#{file_path}"),
              "Contents (last 10 lines):"
            )
            expect(output).to include(*contents.last(10).join("\n"))
            expect(output).to_not include(*contents.first(2).join("\n"))
          end

          it "transmits file data in report" do
            expect(received_report["paths"][path_key]).to match(
              "path" => file_path,
              "exists" => true,
              "type" => "file",
              "mode" => kind_of(String),
              "writable" => boolean,
              "ownership" => {
                "uid" => kind_of(Integer),
                "user" => kind_of(String),
                "gid" => kind_of(Integer),
                "group" => kind_of(String)
              },
              "content" => contents
            )
          end
        end

        context "when file does not exist" do
          before do
            if shared_example_options && shared_example_options[:stub_not_exists]
              allow(File).to receive(:exist?).and_call_original
              expect(File).to receive(:exist?).with(file_path).and_return(false)
            end
            run
          end

          it "outputs file does not exists" do
            expect(output).to include %(Path: "#{file_path}"\n    Exists?: false)
          end

          it "transmits file data in report" do
            expect(received_report["paths"][path_key]).to eq(
              "path" => file_path,
              "exists" => false
            )
          end
        end

        context "when reading the file returns a illegal seek error" do
          before do
            File.write(file_path, "Some content")
            allow(File).to receive(:binread).and_call_original
            expect(File).to receive(:binread).with(file_path, anything,
              anything).and_raise(Errno::ESPIPE)
            run
          end

          it "outputs file does not exists" do
            expect(output).to include %(Read error: Errno::ESPIPE: Illegal seek)
          end

          it "transmits file data in report" do
            expect(received_report["paths"][path_key]).to include(
              "read_error" => "Errno::ESPIPE: Illegal seek"
            )
          end
        end
      end

      describe "ext/mkmf.log" do
        it_behaves_like "diagnose file" do
          let(:filename) { "mkmf.log" }
          let(:path_key) { "ext/mkmf.log" }
          before do
            expect_any_instance_of(Appsignal::CLI::Diagnose::Paths)
              .to receive(:makefile_install_log_path)
              .at_least(:once)
              .and_return(File.join(parent_directory, filename))
          end
        end

        it "outputs header" do
          run
          expect(output).to include("Makefile install log")
        end
      end

      describe "appsignal.log" do
        it_behaves_like "diagnose file", :stub_not_exists => true do
          let(:filename) { "appsignal.log" }
          before do
            ENV["APPSIGNAL_LOG"] = "stdout"
            expect_any_instance_of(Appsignal::Config).to receive(:log_file_path)
              .at_least(:once)
              .and_return(file_path)
          end
        end

        it "outputs header" do
          run
          expect(output).to include("AppSignal log")
        end
      end
    end
  end

  def expect_valid_agent_diagnostics_report(output, working_directory_stat)
    expect(output).to include \
      "Agent diagnostics",
      "  Extension tests\n    Configuration: valid",
      "    Started: started",
      "    Process user id: #{Process.uid}",
      "    Process user group id: #{Process.gid}\n" \
        "    Configuration: valid",
      "    Logger: started",
      "    Working directory user id: #{working_directory_stat.uid}",
      "    Working directory user group id: #{working_directory_stat.gid}",
      "    Working directory permissions: #{working_directory_stat.mode}",
      "    Lock path: writable"
  end

  def hash_with_string_keys(hash)
    hash.transform_keys(&:to_s)
  end
end
