require 'appsignal/cli'

describe Appsignal::CLI do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI }
  before do
    Dir.stub(:pwd => project_fixture_path)
  end
  around do |example|
    capture_stdout(out_stream) { example.run }
  end

  it "should print the help with no arguments, -h and --help" do
    [nil, '-h', '--help'].each do |arg|
      lambda {
        cli.run([arg].compact)
      }.should raise_error(SystemExit)

      out_stream.string.should include 'appsignal <command> [options]'
      out_stream.string.should include \
        'Available commands: demo, diagnose, install, notify_of_deploy'
    end
  end

  it "should print the version with -v and --version" do
    ['-v', '--version'].each do |arg|
      lambda {
        cli.run([arg])
      }.should raise_error(SystemExit)

      out_stream.string.should include 'AppSignal'
      out_stream.string.should include '.'
    end
  end

  it "should print a notice if a command does not exist" do
    lambda {
        cli.run(['nonsense'])
      }.should raise_error(SystemExit)

    out_stream.string.should include "Command 'nonsense' does not exist, run "\
      "appsignal -h to see the help"
  end

  describe "diagnose" do
    it "should call Appsignal::Diagnose.install" do
      Appsignal::CLI::Diagnose.should_receive(:run)

      cli.run([
        'diagnose'
      ])
    end
  end
end
