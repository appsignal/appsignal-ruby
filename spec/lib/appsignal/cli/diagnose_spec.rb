require "appsignal/cli"

describe Appsignal::CLI::Diagnose, :api_stub => true do
  describe ".run" do
    let(:out_stream) { std_stream }
    let(:output) { out_stream.read }
    let(:config) { project_fixture_config }
    let(:cli) { described_class }
    let(:options) { { :environment => config.env } }
    before(:context) { Appsignal.stop }
    before do
      if DependencyHelper.rails_present?
        allow(Rails).to receive(:root).and_return(Pathname.new(config.root_path))
      end
    end
    before :api_stub => true do
      stub_api_request config, "auth"
    end
    after { Appsignal.config = nil }

    def run
      run_within_dir project_fixture_path
    end

    def run_within_dir(chdir)
      Dir.chdir chdir do
        capture_stdout(out_stream) { cli.run(options) }
      end
    end

    it "outputs header and support text" do
      run
      expect(output).to include \
        "AppSignal diagnose",
        "http://docs.appsignal.com/",
        "support@appsignal.com"
    end

    describe "agent information" do
      it "outputs version numbers" do
        run
        gem_path = Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip
        expect(output).to include \
          "Gem version: #{Appsignal::VERSION}",
          "Agent version: #{Appsignal::Extension.agent_version}",
          "Gem install path: #{gem_path}"
      end

      context "with extension" do
        it "outputs extension is loaded" do
          run
          expect(output).to include "Extension loaded: yes"
        end

        it "starts the agent in diagnose mode and outputs a log" do
          run
          expect(output).to include \
            "Agent diagnostics:",
            "Running agent in diagnose mode",
            "Valid config present",
            "Logger initialized successfully",
            "Lock path is writable",
            "Agent diagnose finished"
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
          expect(output).to include "Extension loaded: no"
        end
      end
    end

    describe "host information" do
      it "outputs host information" do
        run
        expect(output).to include \
          "Host information",
          "Architecture: #{RbConfig::CONFIG["host_cpu"]}",
          "Operating System: #{RbConfig::CONFIG["host_os"]}",
          "Ruby version: #{RbConfig::CONFIG["RUBY_VERSION_NAME"]}"
      end

      describe "root user detection" do
        context "when not root user" do
          it "prints no" do
            run
            expect(output).to include "root user: no"
          end
        end

        context "when root user" do
          before do
            allow(Process).to receive(:uid).and_return(0)
            run
          end

          it "prints yes, with warning" do
            expect(output).to include "root user: yes (not recommended)"
          end
        end
      end

      describe "Heroku detection" do
        context "when not on Heroku" do
          it "does not output Heroku detection" do
            expect(output).to_not include("Heroku:")
          end
        end

        context "when on Heroku" do
          before { recognize_as_heroku { run } }

          it "outputs Heroku detection" do
            expect(output).to include("Heroku: true")
          end
        end
      end

      describe "container detection" do
        context "when not in container" do
          before do
            allow(Appsignal::Extension).to receive(:running_in_container?).and_return(false)
            run
          end

          it "outputs: no" do
            expect(output).to include("Running in container: no")
          end
        end

        context "when in container" do
          before do
            allow(Appsignal::Extension).to receive(:running_in_container?).and_return(true)
            run
          end

          it "outputs: yes" do
            expect(output).to include("Running in container: yes")
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
          expect(output).to_not include "Error"
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
          expect(output).to_not include "Error"
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
          expect(output).to_not include "Error"
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
          expect(output).to include("Validating API key: Valid")
        end
      end

      context "with invalid key" do
        before do
          stub_api_request(config, "auth").to_return(:status => 401)
          run
        end

        it "outputs invalid" do
          expect(output).to include("Validating API key: Invalid")
        end
      end

      context "with invalid key" do
        before do
          stub_api_request(config, "auth").to_return(:status => 500)
          run
        end

        it "outputs failure with status code" do
          expect(output).to include("Validating API key: Failed with status 500")
        end
      end
    end

    describe "paths" do
      let(:system_tmp_dir) { Appsignal::Config::SYSTEM_TMP_DIR }
      before do
        FileUtils.mkdir_p(root_path)
        FileUtils.mkdir_p(system_tmp_dir)
      end
      after { FileUtils.rm_rf([root_path, system_tmp_dir]) }

      context "when a directory is not configured" do
        let(:root_path) { File.join(tmp_dir, "writable_path") }
        let(:config) { Appsignal::Config.new(root_path, "production", :log_file => nil) }
        before do
          FileUtils.mkdir_p(File.join(root_path, "log"), :mode => 0555)
          FileUtils.chmod(0555, system_tmp_dir)
          run_within_dir root_path
        end

        it "outputs unconfigured directory" do
          expect(output).to include %(log_file_path: ""\n    - Configured?: no)
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
          expect(output).to include %(root_path: "#{execution_path}"\n    - Exists?: no)
        end
      end

      describe "ownership" do
        context "when a directory is owned by the current user" do
          let(:root_path) { File.join(tmp_dir, "owned_path") }
          let(:config) { Appsignal::Config.new(root_path, "production") }
          let(:process_user) { Etc.getpwuid(Process.uid).name }
          before { run_within_dir root_path }

          it "outputs ownership" do
            expect(output).to include \
              %(root_path: "#{root_path}"\n    - Writable?: yes\n    ) \
                "- Ownership?: yes (file: #{process_user}:#{Process.uid}, "\
                "process: #{process_user}:#{Process.uid})"
          end
        end

        context "when a directory is not owned by the current user" do
          let(:root_path) { File.join(tmp_dir, "not_owned_path") }
          let(:config) { Appsignal::Config.new(root_path, "production") }
          let(:process_user) { Etc.getpwuid(Process.uid).name }
          before do
            stat = File.stat(root_path)
            allow(stat).to receive(:uid).and_return(0)
            allow(File).to receive(:stat).and_return(stat)
            run_within_dir root_path
          end

          it "outputs no ownership" do
            expect(output).to include \
              %(root_path: "#{root_path}"\n    - Writable?: yes\n    ) \
                "- Ownership?: no (file: root:0, process: #{process_user}:#{Process.uid})"
          end
        end
      end

      describe "current_path" do
        let(:root_path) { tmp_dir }
        let(:config) { Appsignal::Config.new(root_path, "production") }
        before { run_within_dir root_path }

        it "outputs current path" do
          expect(output).to include %(current_path: "#{tmp_dir}"\n    - Writable?: yes)
        end
      end

      describe "root_path" do
        let(:system_tmp_log_file) { File.join(system_tmp_dir, "appsignal.log") }
        context "when not writable" do
          let(:root_path) { File.join(tmp_dir, "not_writable_path") }
          let(:config) { Appsignal::Config.new(root_path, "production") }
          before do
            FileUtils.chmod(0555, root_path)
            run_within_dir root_path
          end

          it "outputs not writable root path" do
            expect(output).to include %(root_path: "#{root_path}"\n    - Writable?: no)
          end

          it "log files fall back on system tmp directory" do
            expect(output).to include \
              %(log_dir_path: "#{system_tmp_dir}"\n    - Writable?: yes),
              %(log_file_path: "#{system_tmp_log_file}"\n    - Exists?: no)
          end
        end

        context "when writable" do
          let(:root_path) { File.join(tmp_dir, "writable_path") }
          let(:config) { Appsignal::Config.new(root_path, "production") }

          context "without log dir" do
            before do
              FileUtils.chmod(0777, root_path)
              run_within_dir root_path
            end

            it "outputs writable root path" do
              expect(output).to include %(root_path: "#{root_path}"\n    - Writable?: yes)
            end

            it "log files fall back on system tmp directory" do
              expect(output).to include \
                %(log_dir_path: "#{system_tmp_dir}"\n    - Writable?: yes),
                %(log_file_path: "#{system_tmp_log_file}"\n    - Exists?: no)
            end
          end

          context "with log dir" do
            let(:log_dir) { File.join(root_path, "log") }
            let(:log_file) { File.join(log_dir, "appsignal.log") }
            before { FileUtils.mkdir_p(log_dir) }

            context "when not writable" do
              before do
                FileUtils.chmod(0444, log_dir)
                run_within_dir root_path
              end

              it "log files fall back on system tmp directory" do
                expect(output).to include \
                  %(log_dir_path: "#{system_tmp_dir}"\n    - Writable?: yes),
                  %(log_file_path: "#{system_tmp_log_file}"\n    - Exists?: no)
              end
            end

            context "when writable" do
              context "without log file" do
                before { run_within_dir root_path }

                it "outputs writable but without log file" do
                  expect(output).to include \
                    %(root_path: "#{root_path}"\n    - Writable?: yes),
                    %(log_dir_path: "#{log_dir}"\n    - Writable?: yes),
                    %(log_file_path: "#{log_file}"\n    - Exists?: no)
                end
              end

              context "with log file" do
                context "when writable" do
                  before do
                    FileUtils.touch(log_file)
                    run_within_dir root_path
                  end

                  it "lists log file as writable" do
                    expect(output).to include %(log_file_path: "#{log_file}"\n    - Writable?: yes)
                  end
                end

                context "when not writable" do
                  before do
                    FileUtils.touch(log_file)
                    FileUtils.chmod(0444, log_file)
                    run_within_dir root_path
                  end

                  it "lists log file as not writable" do
                    expect(output).to include %(log_file_path: "#{log_file}"\n    - Writable?: no)
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
          allow(cli).to receive(:gem_path).and_return(gem_path)
        end

        context "when file exists" do
          let(:gem_path) { File.join(tmp_dir, "gem") }
          before do
            FileUtils.mkdir_p ext_path
            File.open log_path, "a" do |f|
              f.write "log line 1"
              f.write "log line 2"
            end
            run
          end

          it "outputs install.log" do
            expect(output).to include \
              %(Path: "#{log_path}"),
              "log line 1",
              "log line 2"
          end

          after { FileUtils.rm_rf(gem_path) }
        end

        context "when file does not exist" do
          let(:gem_path) { File.join(tmp_dir, "non_existent_path") }
          before { run }

          it "outputs install.log" do
            expect(output).to include %(Path: "#{log_path}"\n  File not found.)
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
          expect(output).to include("Extension install log")
        end
      end
    end
  end
end
