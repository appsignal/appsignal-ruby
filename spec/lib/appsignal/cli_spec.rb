require 'appsignal/cli'

describe Appsignal::CLI do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI }
  before do
    Dir.stub(:pwd => project_fixture_path)
    cli.options = {:environment => 'production'}
  end
  around do |example|
    capture_stdout(out_stream) { example.run }
  end

  describe "#config" do
    subject { cli.config }

    it { should be_instance_of(Appsignal::Config) }
    its(:valid?) { should be_true }
  end

  it "should print the help with no arguments, -h and --help" do
    [nil, '-h', '--help'].each do |arg|
      lambda {
        cli.run([arg].compact)
      }.should raise_error(SystemExit)

      out_stream.string.should include 'appsignal <command> [options]'
      out_stream.string.should include 'Available commands: diagnose, install, notify_of_deploy'
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

  describe "install" do
    it "should call Appsignal::Install.install" do
      Appsignal::CLI::Install.should_receive(:run).with(
        'api-key',
        instance_of(Appsignal::Config)
      )

      cli.run([
        'install',
        'api-key'
      ])
    end
  end

  describe "notify_of_deploy" do
    it "should call Appsignal::Install.install" do
      Appsignal::CLI::NotifyOfDeploy.should_receive(:run).with(
        {
           :revision => "aaaaa",
           :user => "thijs",
           :environment => "production",
           :name => "project-production"
        },
        instance_of(Appsignal::Config)
      )

      cli.run([
        'notify_of_deploy',
        '--name=project-production',
        '--revision=aaaaa',
        '--user=thijs',
        '--environment=production'
      ])
    end
  end
end
