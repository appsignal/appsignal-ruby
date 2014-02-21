require 'spec_helper'
require 'appsignal/cli'

describe Appsignal::CLI do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI }
  before do
    @original_stdout = $stdout
    $stdout = out_stream
    ENV['PWD'] = project_fixture_path
    cli.config = nil
    cli.options = {:environment => 'production'}
  end
  after do
    $stdout = @original_stdout
  end

  describe "#logger" do
    it "should be a logger" do
      cli.logger.should be_instance_of(Logger)
    end
  end

  describe "#config" do
    subject { cli.config }

    it { should be_instance_of(Appsignal::Config) }
    its(:loaded?) { should be_true }
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

    out_stream.string.should include "Command 'nonsense' does not exist, run "\
      "appsignal -h to see the help"
  end

  describe "#notify_of_deploy" do
    it "should validate that the config has been loaded and all options have been supplied" do
      cli.should_receive(:validate_config_loaded)
      cli.should_receive(:validate_required_options).with(
        [:revision, :user, :environment]
      )
      Appsignal::Marker.should_receive(:new).and_return(double(:transmit => true))

      cli.notify_of_deploy
    end

    it "should notify of a deploy" do
      marker = double
      Appsignal::Marker.should_receive(:new).with(
        {
          :revision => 'aaaaa',
          :user => 'thijs'
        },
        kind_of(Appsignal::Config),
        kind_of(Logger)
      ).and_return(marker)
      marker.should_receive(:transmit)

      cli.run([
        'notify_of_deploy',
        '--revision=aaaaa',
        '--user=thijs',
        '--environment=production'
      ])
    end

    it "should notify of a deploy with no config file and a name specified" do
      ENV['PWD'] = '/nonsense'
      ENV['APPSIGNAL_PUSH_API_KEY'] = 'key'

      marker = double
      Appsignal::Marker.should_receive(:new).with(
        {
          :revision => 'aaaaa',
          :user => 'thijs'
        },
        kind_of(Appsignal::Config),
        kind_of(Logger)
      ).and_return(marker)
      marker.should_receive(:transmit)

      cli.run([
        'notify_of_deploy',
        '--name=project-production',
        '--revision=aaaaa',
        '--user=thijs',
        '--environment=production'
      ])

      cli.config[:name].should == 'project-production'
    end
  end

  # protected

  describe "#validate_required_options" do
    let(:required_options) { [:option_1, :option_2, :option_3] }

    it "should do nothing with all options supplied" do
      cli.options = {
        :option_1 => 1,
        :option_2 => 2,
        :option_3 => 3
      }
      cli.send(
        :validate_required_options,
        required_options
      )
      out_stream.string.should be_empty
    end

    it "should print a message with one option missing and exit" do
      cli.options = {
        :option_1 => 1,
        :option_2 => 2
      }
      lambda {
        cli.send(
          :validate_required_options,
          required_options
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include('Missing options: option_3')
    end

    it "should print a message with multiple options missing and exit" do
      cli.options = {
        :option_1 => 1,
        :option_2 => ''
      }
      lambda {
        cli.send(
          :validate_required_options,
          required_options
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include("Missing options: option_2, option_3")
    end
  end

  describe "#validate_config_loaded" do
    context "when config is present" do
      it "should do nothing" do
        cli.send(:validate_config_loaded)
        out_stream.string.should be_empty
      end
    end

    context "when config is not present" do
      before { cli.options = {:environment => 'nonsense'} }

      it "should print a message and exit" do
        lambda {
          cli.send(:validate_config_loaded)
        }.should raise_error(SystemExit)
        out_stream.string.should include('Exiting: No config file or push api key env var found')
      end
    end
  end
end
