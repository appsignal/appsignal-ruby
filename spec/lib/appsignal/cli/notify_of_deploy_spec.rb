require 'spec_helper'
require 'appsignal/cli'

describe Appsignal::CLI::NotifyOfDeploy do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI::NotifyOfDeploy }
  let(:config) { Appsignal::Config.new(project_fixture_path, {}) }
  let(:marker_data) { {:revision => 'aaaaa', :user => 'thijs', :environment => 'production'} }
  before do
    @original_stdout = $stdout
    $stdout = out_stream
    config.stub(:active? => true)
  end
  after do
    $stdout = @original_stdout
  end

  describe ".run" do
    it "should validate that the config has been loaded and all options have been supplied" do
      cli.should_receive(:validate_active_config)
      cli.should_receive(:validate_required_options).with(
        {},
        [:revision, :user, :environment]
      )
      Appsignal::Marker.should_receive(:new).and_return(double(:transmit => true))

      cli.run({}, config)
    end

    it "should notify of a deploy" do
      marker = double
      Appsignal::Marker.should_receive(:new).with(
        {
          :revision => 'aaaaa',
          :user => 'thijs'
        },
        kind_of(Appsignal::Config),
        nil
      ).and_return(marker)
      marker.should_receive(:transmit)

      cli.run(marker_data, config)
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
        nil
      ).and_return(marker)
      marker.should_receive(:transmit)

      cli.run(marker_data, config)
    end
  end

  describe "#validate_required_options" do
    let(:required_options) { [:option_1, :option_2, :option_3] }

    it "should do nothing with all options supplied" do
      cli.send(
        :validate_required_options,
        {
          :option_1 => 1,
          :option_2 => 2,
          :option_3 => 3
        },
        required_options
      )
      out_stream.string.should be_empty
    end

    it "should print a message with one option missing and exit" do
      lambda {
        cli.send(
          :validate_required_options,
          {
            :option_1 => 1,
            :option_2 => 2
          },
          required_options
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include('Missing options: option_3')
    end

    it "should print a message with multiple options missing and exit" do
      lambda {
        cli.send(
          :validate_required_options,
          {
            :option_1 => 1,
            :option_2 => ''
          },
          required_options
        )
      }.should raise_error(SystemExit)
      out_stream.string.should include("Missing options: option_2, option_3")
    end
  end

  describe "#validate_active_config" do
    context "when config is present" do
      it "should do nothing" do
        cli.send(:validate_active_config, config)
        out_stream.string.should be_empty
      end
    end

    context "when config is not active" do
      before { config.stub(:active? => false) }

      it "should print a message and exit" do
        lambda {
          cli.send(:validate_active_config, config)
        }.should raise_error(SystemExit)
        out_stream.string.should include('Exiting: No config file or push api key env var found')
      end
    end
  end
end
