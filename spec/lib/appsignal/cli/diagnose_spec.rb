require "appsignal/cli"

describe Appsignal::CLI::Diagnose do
  describe ".run" do
    let(:out_stream) { StringIO.new }
    let(:config) { project_fixture_config }
    let(:cli) { described_class }
    let(:output) { out_stream.string }
    before do
      ENV["APPSIGNAL_APP_ENV"] = "production"
      stub_api_request config, "auth"
    end
    after { Appsignal.config = nil }
    around { |example| capture_stdout(out_stream) { example.run } }

    def run
      run_within_dir project_fixture_path
    end

    def run_within_dir(chdir)
      Dir.chdir chdir do
        cli.run
      end
    end

    it "outputs header and support text" do
      run
      expect(output).to include \
        "AppSignal diagnose",
        "http://docs.appsignal.com/",
        "support@appsignal.com"
    end

    it "outputs version numbers" do
      run
      gem_path = Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip
      expect(output).to include \
        "Gem version: #{Appsignal::VERSION}",
        "Agent version: #{Appsignal::Extension.agent_version}",
        "Gem install path: #{gem_path}"
    end

    it "outputs host information" do
      run
      expect(output).to include \
        "Host information",
        "Architecture: #{RbConfig::CONFIG["host_cpu"]}",
        "Operating System: #{RbConfig::CONFIG["host_os"]}",
        "Ruby version: #{RbConfig::CONFIG["RUBY_VERSION_NAME"]}"
    end

    describe "configuration" do
      context "without environment" do
        let(:config) { project_fixture_config("") }
        before do
          ENV["APPSIGNAL_APP_ENV"] = ""
          run
        end

        it "outputs a warning that no config is loaded" do
          expect(output).to include \
            "Environment: \n    Warning: No environment set, no config loaded!",
            "  APPSIGNAL_APP_ENV=production appsignal diagnose"
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
        before do
          ENV["APPSIGNAL_APP_ENV"] = "foobar"
          run
        end

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

    describe "API key validation" do
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
      before { FileUtils.mkdir_p(root_path) }

      context "when a directory is writable" do
        let(:root_path) { File.join(tmp_dir, "writable_path") }
        let(:log_file) { File.join(root_path, "appsignal.log") }
        let(:config) { Appsignal::Config.new(root_path, "production") }

        context "without log file" do
          before { run_within_dir root_path }

          it "outputs writable" do
            expect(output).to include \
              "Required paths",
              %(root_path: "#{root_path}" - Writable),
              %(log_file_path: "#{log_file}" - Does not exist)
          end
        end

        context "with log file" do
          context "when writable" do
            before do
              FileUtils.touch(log_file)
              run_within_dir root_path
            end

            it "lists log file as writable" do
              expect(output).to include \
                %(root_path: "#{root_path}" - Writable),
                %(log_file_path: "#{File.join(root_path, "appsignal.log")}" - Writable)
            end
          end

          context "when not writable" do
            before do
              FileUtils.touch(log_file)
              FileUtils.chmod(0444, log_file)
              run_within_dir root_path
            end

            it "lists log file as not writable" do
              expect(output).to include \
                %(root_path: "#{root_path}" - Writable),
                %(log_file_path: "#{File.join(root_path, "appsignal.log")}" - Not writable)
            end
          end
        end
      end

      context "when a directory is not writable" do
        let(:root_path) { File.join(tmp_dir, "not_writable_path") }
        let(:config) { Appsignal::Config.new(root_path, "production") }
        before do
          FileUtils.chmod(0555, root_path)
          run_within_dir root_path
        end

        it "outputs not writable" do
          expect(output).to include \
            "Required paths",
            %(root_path: "#{root_path}" - Not writable),
            %(log_file_path: "" - Not writable)
        end
      end

      after { FileUtils.rm_rf(root_path) }
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
