require "appsignal/cli"

describe Appsignal::CLI::Diagnose, :api_stub => true, :report => true do
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
    let(:cli) { described_class }
    let(:options) { { :environment => config.env } }
    let(:gem_path) { Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip }
    let(:received_report) { DiagnosticsReportEndpoint.received_report }
    let(:process_user) { Etc.getpwuid(Process.uid).name }
    before(:context) { Appsignal.stop }
    before do
      # Clear previous reports
      DiagnosticsReportEndpoint.clear_report!
      if cli.instance_variable_defined? :@data
        # Because this is saved on the class rather than an instance of the
        # class we need to clear it like this in case a certain test doesn't
        # generate a report.
        cli.remove_instance_variable :@data
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
    before :report => true do
      send_diagnostics_report
      stub_diagnostics_report_request.to_rack(DiagnosticsReportEndpoint)
    end
    before(:report => false) { dont_send_diagnostics_report }
    after { Appsignal.config = nil }

    def run
      run_within_dir project_fixture_path
    end

    def run_within_dir(chdir)
      prepare_cli_input
      Dir.chdir chdir do
        capture_stdout(out_stream) { cli.run(options) }
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

    def send_diagnostics_report
      add_cli_input "y"
    end

    def dont_send_diagnostics_report
      add_cli_input "n"
    end

    it "outputs header and support text" do
      run
      expect(output).to include \
        "AppSignal diagnose",
        "http://docs.appsignal.com/",
        "support@appsignal.com"
    end

    describe "report" do
      context "when user wants to send report" do
        it "sends report" do
          run
          expect(output).to include "Diagnostics report",
            "Send diagnostics report to AppSignal? (Y/n): ",
            "Please email us at support@appsignal.com with the following\n  support token."
        end

        it "outputs the support token from the server" do
          run
          expect(output).to include "Your support token: my_support_token"
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

      context "when user doesn't want to send report", :report => false do
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
          "Gem version: #{Appsignal::VERSION}",
          "Agent version: #{Appsignal::Extension.agent_version}",
          "Agent architecture: #{Appsignal::System.installed_agent_architecture}",
          "Gem install path: #{gem_path}"
      end

      it "transmits version numbers in report" do
        expect(received_report).to include(
          "library" => {
            "language" => "ruby",
            "package_version" => Appsignal::VERSION,
            "agent_version" => Appsignal::Extension.agent_version,
            "agent_architecture" => Appsignal::System.installed_agent_architecture,
            "package_install_path" => gem_path,
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
        end

        it "transmits extension_loaded: false in report" do
          expect(received_report["library"]["extension_loaded"]).to eq(false)
        end
      end
    end

    describe "agent diagnostics" do
      let(:working_directory_stat) { File.stat("/tmp/appsignal") }

      it "starts the agent in diagnose mode and outputs the report" do
        run
        working_directory_stat = File.stat("/tmp/appsignal")
        expect(output).to include \
          "Agent diagnostics",
          "  Extension config: valid",
          "  Agent started: started",
          "  Agent user id: #{Process.uid}",
          "  Agent user group id: #{Process.gid}",
          "  Agent config: valid",
          "  Agent logger: started",
          "  Agent working directory user id: #{working_directory_stat.uid}",
          "  Agent working directory user group id: #{working_directory_stat.gid}",
          "  Agent working directory permissions: #{working_directory_stat.mode}",
          "  Agent lock path: writable"
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
              "gid" => { "result" => Process.gid }
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
          expect(output).to include \
            "Agent diagnostics",
            "  Extension config: valid",
            "  Agent started: started",
            "  Agent config: valid",
            "  Agent logger: started",
            "  Agent lock path: writable"
        end
      end

      context "when the extention returns invalid JSON" do
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
            "  Extension config: invalid",
            "  Agent started: -",
            "  Agent config: -",
            "  Agent logger: -",
            "  Agent lock path: -"
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
            "  Extension config: valid",
            "  Agent started: not started\n    Error: some-error"
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
            "  Extension config: valid",
            "  Agent config: invalid\n    Output: some output"
        end
      end
    end

    describe "host information" do
      let(:rbconfig) { RbConfig::CONFIG }
      let(:language_version) { "#{rbconfig["ruby_version"]}-p#{rbconfig["PATCHLEVEL"]}" }

      it "outputs host information" do
        run
        expect(output).to include \
          "Host information",
          "Architecture: #{rbconfig["host_cpu"]}",
          "Operating System: #{rbconfig["host_os"]}",
          "Ruby version: #{language_version}"
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
        expect(host_report).to eq(
          "architecture" => rbconfig["host_cpu"],
          "os" => rbconfig["host_os"],
          "language_version" => language_version,
          "heroku" => false,
          "root" => false
        )
      end

      describe "root user detection" do
        context "when not root user" do
          it "outputs false" do
            run
            expect(output).to include "root user: false"
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
            expect(output).to include "root user: true (not recommended)"
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
        before do
          ENV.delete("RAILS_ENV") # From spec_helper
          ENV.delete("RACK_ENV")
          run_within_dir tmp_dir
        end

        it "outputs a warning that no config is loaded" do
          expect(output).to include \
            "Environment: \n    Warning: No environment set, no config loaded!",
            "  appsignal diagnose --environment=production"
        end

        it "outputs config defaults" do
          expect(output).to include("Configuration")
          Appsignal::Config::DEFAULT_CONFIG.each do |key, value|
            expect(output).to include("#{key}: #{value}")
          end
        end
      end

      context "with configured environment" do
        before { run }

        it "outputs environment" do
          expect(output).to include("Environment: production")
        end

        it "outputs configuration" do
          expect(output).to include("Configuration")
          Appsignal.config.config_hash.each do |key, value|
            expect(output).to include("#{key}: #{value}")
          end
        end
      end

      context "with unconfigured environment" do
        let(:config) { project_fixture_config("foobar") }
        before { run_within_dir tmp_dir }

        it "outputs environment" do
          expect(output).to include("Environment: foobar")
        end

        it "outputs config defaults" do
          expect(output).to include("Configuration")
          Appsignal::Config::DEFAULT_CONFIG.each do |key, value|
            expect(output).to include("#{key}: #{value}")
          end
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
            "Validating Push API key: Failed with status 500\n" +
            %("Could not confirm authorization: 500")
        end

        it "transmits validation in report" do
          expect(received_report).to include(
            "validation" => {
              "push_api_key" => %(Failed with status 500\n\"Could not confirm authorization: 500")
            }
          )
        end
      end
    end

    describe "paths" do
      let(:system_tmp_dir) { Appsignal::Config.system_tmp_dir }
      before do
        FileUtils.mkdir_p(root_path)
        FileUtils.mkdir_p(system_tmp_dir)
      end
      after { FileUtils.rm_rf([root_path, system_tmp_dir]) }

      describe "report" do
        let(:root_path) { tmp_dir }

        it "adds paths to the report" do
          run
          expect(received_report["paths"].keys)
            .to match_array(%w[root_path working_dir log_dir_path log_file_path])
        end
      end

      context "when a directory is not configured" do
        let(:root_path) { File.join(tmp_dir, "writable_path") }
        let(:config) { Appsignal::Config.new(root_path, "production", :log_file => nil) }
        before do
          FileUtils.mkdir_p(File.join(root_path, "log"), :mode => 0o555)
          FileUtils.chmod(0o555, system_tmp_dir)
          run_within_dir root_path
        end

        it "outputs unconfigured directory" do
          expect(output).to include %(log_file_path: ""\n    Configured?: false)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["log_file_path"]).to eq(
            "path" => nil,
            "configured" => false,
            "exists" => false,
            "writable" => false
          )
        end
      end

      context "when a directory does not exist" do
        let(:root_path) { tmp_dir }
        let(:execution_path) { File.join(tmp_dir, "not_existing_dir") }
        let(:config) { Appsignal::Config.new(execution_path, "production") }
        before do
          allow(Dir).to receive(:pwd).and_return(execution_path)
          run_within_dir tmp_dir
        end

        it "outputs not existing path" do
          expect(output).to include %(root_path: "#{execution_path}"\n    Exists?: false)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["root_path"]).to eq(
            "path" => execution_path,
            "configured" => true,
            "exists" => false,
            "writable" => false
          )
        end
      end

      describe "ownership" do
        let(:config) { Appsignal::Config.new(root_path, "production") }

        context "when a directory is owned by the current user" do
          let(:root_path) { File.join(tmp_dir, "owned_path") }
          before { run_within_dir root_path }

          it "outputs ownership" do
            expect(output).to include \
              %(root_path: "#{root_path}"\n    Writable?: true\n    ) \
                "Ownership?: true (file: #{process_user}:#{Process.uid}, "\
                "process: #{process_user}:#{Process.uid})"
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["root_path"]).to eq(
              "path" => root_path,
              "configured" => true,
              "exists" => true,
              "writable" => true,
              "ownership" => { "uid" => Process.uid, "user" => process_user }
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
              %(root_path: "#{root_path}"\n    Writable?: true\n    ) \
                "Ownership?: false (file: root:0, process: #{process_user}:#{Process.uid})"
          end
        end
      end

      describe "working_dir" do
        let(:root_path) { tmp_dir }
        let(:config) { Appsignal::Config.new(root_path, "production") }
        before { run_within_dir root_path }

        it "outputs current path" do
          expect(output).to include %(working_dir: "#{tmp_dir}"\n    Writable?: true)
        end

        it "transmits path data in report" do
          expect(received_report["paths"]["working_dir"]).to eq(
            "path" => tmp_dir,
            "configured" => true,
            "exists" => true,
            "writable" => true,
            "ownership" => { "uid" => Process.uid, "user" => process_user }
          )
        end
      end

      describe "root_path" do
        let(:system_tmp_log_file) { File.join(system_tmp_dir, "appsignal.log") }
        let(:config) { Appsignal::Config.new(root_path, "production") }

        context "when not writable" do
          let(:root_path) { File.join(tmp_dir, "not_writable_path") }
          before do
            FileUtils.chmod(0o555, root_path)
            run_within_dir root_path
          end

          it "outputs not writable root path" do
            expect(output).to include %(root_path: "#{root_path}"\n    Writable?: false)
          end

          it "log files fall back on system tmp directory" do
            expect(output).to include \
              %(log_dir_path: "#{system_tmp_dir}"\n    Writable?: true),
              %(log_file_path: "#{system_tmp_log_file}"\n    Exists?: false)
          end

          it "transmits path data in report" do
            expect(received_report["paths"]["root_path"]).to eq(
              "path" => root_path,
              "configured" => true,
              "exists" => true,
              "writable" => false,
              "ownership" => { "uid" => Process.uid, "user" => process_user }
            )
          end
        end

        context "when writable" do
          let(:root_path) { File.join(tmp_dir, "writable_path") }

          context "without log dir" do
            before do
              FileUtils.chmod(0o777, root_path)
              run_within_dir root_path
            end

            it "outputs writable root path" do
              expect(output).to include %(root_path: "#{root_path}"\n    Writable?: true)
            end

            it "log files fall back on system tmp directory" do
              expect(output).to include \
                %(log_dir_path: "#{system_tmp_dir}"\n    Writable?: true),
                %(log_file_path: "#{system_tmp_log_file}"\n    Exists?: false)
            end

            it "transmits path data in report" do
              expect(received_report["paths"]["root_path"]).to eq(
                "path" => root_path,
                "configured" => true,
                "exists" => true,
                "writable" => true,
                "ownership" => { "uid" => Process.uid, "user" => process_user }
              )
            end
          end

          context "with log dir" do
            let(:log_dir) { File.join(root_path, "log") }
            let(:log_file) { File.join(log_dir, "appsignal.log") }
            before { FileUtils.mkdir_p(log_dir) }

            context "when not writable" do
              before do
                FileUtils.chmod(0o444, log_dir)
                run_within_dir root_path
              end

              it "log files fall back on system tmp directory" do
                expect(output).to include \
                  %(log_dir_path: "#{system_tmp_dir}"\n    Writable?: true),
                  %(log_file_path: "#{system_tmp_log_file}"\n    Exists?: false)
              end

              it "transmits path data in report" do
                expect(received_report["paths"]["log_dir_path"]).to be_kind_of(Hash)
                expect(received_report["paths"]["log_file_path"]).to be_kind_of(Hash)
              end
            end

            context "when writable" do
              context "without log file" do
                before { run_within_dir root_path }

                it "outputs writable but without log file" do
                  expect(output).to include \
                    %(root_path: "#{root_path}"\n    Writable?: true),
                    %(log_dir_path: "#{log_dir}"\n    Writable?: true),
                    %(log_file_path: "#{log_file}"\n    Exists?: false)
                end

                it "transmits path data in report" do
                  expect(received_report["paths"]["log_dir_path"]).to be_kind_of(Hash)
                  expect(received_report["paths"]["log_file_path"]).to be_kind_of(Hash)
                end
              end

              context "with log file" do
                context "when writable" do
                  before do
                    FileUtils.touch(log_file)
                    run_within_dir root_path
                  end

                  it "lists log file as writable" do
                    expect(output).to include %(log_file_path: "#{log_file}"\n    Writable?: true)
                  end

                  it "transmits path data in report" do
                    expect(received_report["paths"]["log_dir_path"]).to be_kind_of(Hash)
                    expect(received_report["paths"]["log_file_path"]).to be_kind_of(Hash)
                  end
                end

                context "when not writable" do
                  before do
                    FileUtils.touch(log_file)
                    FileUtils.chmod(0o444, log_file)
                    run_within_dir root_path
                  end

                  it "lists log file as not writable" do
                    expect(output).to include %(log_file_path: "#{log_file}"\n    Writable?: false)
                  end

                  it "transmits path data in report" do
                    expect(received_report["paths"]["log_dir_path"]).to be_kind_of(Hash)
                    expect(received_report["paths"]["log_file_path"]).to be_kind_of(Hash)
                  end
                end
              end
            end
          end
        end
      end
    end

    describe "logs" do
      shared_examples "ext log file" do |log_file|
        let(:ext_path) { File.join(gem_path, "ext") }
        let(:log_path) { File.join(ext_path, log_file) }
        before do
          FileUtils.mkdir_p ext_path
          allow(cli).to receive(:gem_path).and_return(gem_path)
        end
        after { FileUtils.rm_rf ext_path }

        context "when file exists" do
          let(:gem_path) { File.join(tmp_dir, "gem") }
          let(:log_content) do
            [
              "log line 1",
              "log line 2"
            ]
          end
          before do
            File.open log_path, "a" do |f|
              log_content.each do |line|
                f.puts line
              end
            end
            run
          end

          it "outputs install.log" do
            expect(output).to include(%(Path: "#{log_path}"))
            expect(output).to include(*log_content)
          end

          it "transmits log data in report" do
            expect(received_report["logs"][File.join("ext", log_file)]).to eq(
              "path" => log_path,
              "exists" => true,
              "content" => log_content
            )
          end

          after { FileUtils.rm_rf(gem_path) }
        end

        context "when file does not exist" do
          let(:gem_path) { File.join(tmp_dir, "gem_without_log_files") }
          before { run }

          it "outputs install.log" do
            expect(output).to include %(Path: "#{log_path}"\n    File not found.)
          end

          it "transmits log data in report" do
            expect(received_report["logs"][File.join("ext", log_file)]).to eq(
              "path" => log_path,
              "exists" => false
            )
          end
        end
      end

      describe "install.log" do
        it_behaves_like "ext log file", "install.log"

        it "outputs header" do
          run
          expect(output).to include("Extension install log")
        end
      end

      describe "mkmf.log" do
        it_behaves_like "ext log file", "mkmf.log"

        it "outputs header" do
          run
          expect(output).to include("Makefile install log")
        end
      end
    end
  end
end
