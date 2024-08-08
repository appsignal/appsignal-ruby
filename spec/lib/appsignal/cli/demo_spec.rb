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
end
