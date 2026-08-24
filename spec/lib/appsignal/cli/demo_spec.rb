require "appsignal/cli"

describe Appsignal::CLI::Demo do
  include CLIHelpers

  let(:options) { {} }
  let(:out_stream) { std_stream }
  let(:output) { out_stream.read }
  before(:context) { Appsignal.stop }

  def run
    run_within_dir project_fixture_path
  end

  def run_within_dir(chdir)
    Dir.chdir chdir do
      capture_stdout(out_stream) { run_cli("demo", options) }
    end
  end

  context "without configuration" do
    it "returns an error" do
      expect { run_within_dir tmp_dir }.to raise_error(SystemExit)

      expect(output).to include("Error: Unable to start the AppSignal agent")
    end
  end

  context "with configuration" do
    before do
      # Ignore sleeps to speed up the test
      allow(Appsignal::Demo).to receive(:sleep)
    end
    let(:options) { { :environment => "development" } }

    it "calls Appsignal::Demo transmitter" do
      expect(Appsignal::Demo).to receive(:transmit).and_return(true)
      run
    end

    it "outputs message" do
      run
      expect(output).to include("Demonstration sample data sent!")
    end
  end

  if DependencyHelper.rails_present?
    context "with a Rails app" do
      let(:root_path) { File.join(tmp_dir, "demo_test_app_#{SecureRandom.uuid}") }
      before { FileUtils.cp_r(rails_project_with_config_rb_fixture_path, root_path) }
      after { FileUtils.rm_rf(root_path) }

      # Run the command in a process of its own. This test suite loads Rails
      # itself, so a `config/appsignal.rb` file that uses Rails would work here
      # even when the command does not load the app. Booting a Rails app in
      # this process also disturbs the specs that run after it.
      def run_demo_command
        binary = File.join(DirectoryHelper.project_dir, "bin/appsignal")
        env = { "BUNDLE_GEMFILE" => Bundler.default_gemfile.to_s }
        options = { :chdir => root_path, :err => [:child, :out] }
        Bundler.with_unbundled_env do
          IO.popen([env, "bundle", "exec", binary, "demo", "--environment=test", options], &:read)
        end
      end

      it "loads the app, so its config file can use the application" do
        expect(run_demo_command).to include("Demonstration sample data sent!")
      end
    end
  end
end
