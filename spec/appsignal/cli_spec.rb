require 'spec_helper'

describe Appsignal::CLI do
  let(:out_stream) { StringIO.new }
  let(:error_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI }
  before :each do
     $stdout, $stderr = out_stream, error_stream
  end

  describe "#logger" do
    it "should be a logger" do
      cli.logger.should be_instance_of(Logger)
    end
  end

  it "should print a message if there is no config file" do
    File.stub(:exists? => false)
    lambda {
        cli.run([])
      }.should raise_error(SystemExit)
      out_stream.string.should include 'No config file present at config/appsignal.yml'
      out_stream.string.should include 'Log in to https://appsignal.com to get instructions on how to generate the config file.'
  end

  it "should print the help with no arguments, -h and --help" do
    [nil, '-h', '--help'].each do |arg|
      lambda {
        cli.run([arg].compact)
      }.should raise_error(SystemExit)

      out_stream.string.should include 'appsignal <command> [options]'
      out_stream.string.should include 'Available commands: notify_of_deploy'
    end
  end

  it "should print the version with -v and --version" do
    ['-v', '--version'].each do |arg|
      lambda {
        cli.run([arg])
      }.should raise_error(SystemExit)

      out_stream.string.should include 'Appsignal'
      out_stream.string.should include '.'
    end
  end

  it "should print a notice if a command does not exist" do
    lambda {
        cli.run(['nonsense'])
      }.should raise_error(SystemExit)

      out_stream.string.should include "Command 'nonsense' does not exist, run appsignal -h to see the help"
  end

  describe "#validate_required_options" do
    let(:required_options) { [:option_1, :option_2, :option_3] }

    it "should do nothing with all options supplied" do
      cli.validate_required_options(
        required_options,
        :option_1 => 1,
        :option_2 => 2,
        :option_3 => 3
      )
      out_stream.string.should be_empty
    end

    it "should print a message with one option missing" do
      lambda {
        cli.validate_required_options(
          required_options,
          :option_1 => 1,
          :option_2 => 2
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include("Missing options: option_3")
    end

    it "should print a message with multiple options missing" do
      lambda {
        cli.validate_required_options(
          required_options,
          :option_1 => 1,
          :option_2 => ''
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include("Missing options: option_2, option_3")
    end
  end

  describe "notify_of_deploy" do
    it "should validate that all options have been supplied" do
      options = {}
      cli.should_receive(:validate_required_options).with(
        [:revision, :repository, :user, :environment],
        options
      )
      cli.notify_of_deploy(options)
    end

    it "should notify of a deploy" do
      transmitter = double
      Appsignal::Transmitter.should_receive(:new).with(
        'http://localhost:3000/1',
        'markers',
        'abc'
      ).and_return(transmitter)
      transmitter.should_receive(:transmit).with(
        :revision => 'aaaaa',
        :repository => 'git@github.com:our/project.git',
        :user => 'thijs'
      )

      cli.run([
        'notify_of_deploy',
        '--revision=aaaaa',
        '--repository=git@github.com:our/project.git',
        '--user=thijs',
        '--environment=production'
      ])
    end
  end
end
