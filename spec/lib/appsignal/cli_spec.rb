require "appsignal/cli"

describe Appsignal::CLI do
  let(:out_stream) { std_stream }
  let(:output) { out_stream.read }
  let(:cli) { Appsignal::CLI }
  before { allow(Dir).to receive(:pwd).and_return(project_fixture_path) }

  it "should print the help with no arguments, -h and --help" do
    [nil, "-h", "--help"].each do |arg|
      expect do
        capture_stdout(out_stream) do
          cli.run([arg].compact)
        end
      end.to raise_error(SystemExit)

      expect(output).to include "appsignal <command> [options]"
      expect(output).to include \
        "Available commands: demo, diagnose, install"
    end
  end

  it "should print the version with -v and --version" do
    ["-v", "--version"].each do |arg|
      expect do
        capture_stdout(out_stream) do
          cli.run([arg])
        end
      end.to raise_error(SystemExit)

      expect(output).to include "AppSignal"
      expect(output).to include "."
    end
  end

  it "should print a notice if a command does not exist" do
    expect do
      capture_stdout(out_stream) do
        cli.run(["nonsense"])
      end
    end.to raise_error(SystemExit)

    expect(output).to include "Command 'nonsense' does not exist, run " \
      "appsignal -h to see the help"
  end

  describe "diagnose" do
    it "should call Appsignal::Diagnose.install" do
      expect(Appsignal::CLI::Diagnose).to receive(:run)

      cli.run([
        "diagnose"
      ])
    end
  end
end
