require 'spec_helper'

describe Appsignal::Config do
  let(:logger_parameter) { [] }
  let(:path) { Dir.pwd }
  let(:config) { Appsignal::Config.new(path, 'test', *logger_parameter) }

  describe "#load" do
    subject { config.load }

    it "should never have logged an error" do
      Appsignal.logger.should_not_receive(:error)
      subject
    end

    it {
      should == {
        :ignore_exceptions => [],
        :endpoint => 'http://localhost:3000/1',
        :slow_request_threshold => 200,
        :api_key => 'ghi',
        :active => true
      }
    }

    context 'when there is no config file' do
      before { Dir.stub(:pwd => '/not/existing') }

      it { should be_nil }
    end

    context "the env is not in the config" do
      before { config.stub(:current_environment_present => false) }

      it { should be_nil }
    end

    context "when an api key is used for more then one environment" do
      before { config.stub(:used_unique_api_keys => false) }

      it { should be_nil }
    end
  end

  # protected

  describe "#load_configurations_from_disk" do
    subject do
      config.send(:load_configurations_from_disk)
      config.configurations
    end

    context "when the file is present" do
      before { config.should_not_receive(:carefully_log_error) }

      it { should_not be_empty }
    end

    context "when the file is not present" do
      before do
        config.should_receive(:carefully_log_error)
        config.stub(:project_path => '/non/existing')
      end

      it { should be_empty }
    end
  end

  describe "#used_unique_api_keys" do
    let(:env) { {:api_key => :foo} }
    subject { config.send(:used_unique_api_keys) }

    context "when using all unique keys" do
      before do
        config.should_not_receive(:carefully_log_error)
        config.stub(:configurations => {1 => env})
      end

      it { should be_true }
    end

    context "when using non-unique keys" do
      before do
        config.should_receive(:carefully_log_error).
          with("Duplicate API keys found in appsignal.yml")
        config.stub(:configurations => {:production => env, :staging => env})
      end

      it { should be_false }
    end
  end

  describe "#current_environment_present" do
    subject { config.send(:current_environment_present) }

    context "when the current environment is present" do
      before do
        config.should_not_receive(:carefully_log_error)
        config.stub(:configurations => {:test => :foo})
      end

      it { should be_true }
    end

    context "when the current environment is absent" do
      before do
        config.should_receive(:carefully_log_error).
          with("config for 'test' not found")
        config.stub(:configurations => {})
      end

      it { should be_false }
    end
  end
end
