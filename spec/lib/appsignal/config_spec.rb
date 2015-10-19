require 'spec_helper'

describe Appsignal::Config do
  subject { config }

  describe "with a config file" do
    let(:config) { project_fixture_config('production') }

    it "should not log an error" do
      Appsignal::Config.any_instance.should_not_receive(:carefully_log_error)
      subject
    end

    its(:valid?)  { should be_true }
    its(:active?) { should be_true }

    it "should merge with the default config and fill the config hash" do
      subject.config_hash.should == {
        :debug                          => false,
        :ignore_errors                  => [],
        :ignore_actions                 => [],
        :instrument_net_http            => true,
        :skip_session_data              => false,
        :send_params                    => true,
        :endpoint                       => 'https://push.appsignal.com',
        :push_api_key                   => 'abc',
        :name                           => 'TestApp',
        :active                         => true,
        :enable_frontend_error_catching => false,
        :frontend_error_catching_path   => '/appsignal_error_catcher',
        :enable_allocation_tracking     => true,
        :enable_gc_instrumentation      => true
      }
    end

    context "when there is a pre 0.12 style endpoint" do
      let(:config) { project_fixture_config('production', :endpoint => 'https://push.appsignal.com/1') }

      it "should strip the path" do
        subject[:endpoint].should == 'https://push.appsignal.com'
      end
    end

    describe "#[]" do
      it "should get the value for an existing key" do
        subject[:push_api_key].should == 'abc'
      end

      it "should return nil for a non-existing key" do
        subject[:nonsense].should be_nil
      end
    end

    describe "#write_to_environment" do
      before do
        subject.config_hash[:http_proxy]     = 'http://localhost'
        subject.config_hash[:ignore_actions] = ['action1', 'action2']
        subject.write_to_environment
      end

      it "should write the current config to env vars" do
        ENV['APPSIGNAL_ACTIVE'].should            == 'true'
        ENV['APPSIGNAL_APP_PATH'].should          end_with('spec/support/project_fixture')
        ENV['APPSIGNAL_AGENT_PATH'].should        end_with('/ext')
        ENV['APPSIGNAL_DEBUG_LOGGING'].should     == 'false'
        ENV['APPSIGNAL_PUSH_API_ENDPOINT'].should == 'https://push.appsignal.com'
        ENV['APPSIGNAL_PUSH_API_KEY'].should      == 'abc'
        ENV['APPSIGNAL_APP_NAME'].should          == 'TestApp'
        ENV['APPSIGNAL_ENVIRONMENT'].should       == 'production'
        ENV['APPSIGNAL_AGENT_VERSION'].should     == Appsignal::Extension.agent_version
        ENV['APPSIGNAL_HTTP_PROXY'].should        == 'http://localhost'
        ENV['APPSIGNAL_IGNORE_ACTIONS'].should    == 'action1,action2'
      end
    end

    context "if the env is passed as a symbol" do
      let(:config) { project_fixture_config(:production) }

      its(:active?) { should be_true }
    end

    context "and there's config in the environment" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY'] = 'push_api_key'
        ENV['APPSIGNAL_DEBUG'] = 'true'
      end

      it "should ignore env vars that are present in the config file" do
        subject[:push_api_key].should == 'abc'
      end

      it "should use env vars that are not present in the config file" do
        subject[:debug].should == true
      end
    end

    context "and there is an initial config" do
      let(:config) { project_fixture_config('production', :name => 'Initial name', :initial_key => 'value') }

      it "should merge with the config" do
        subject[:name].should == 'TestApp'
        subject[:initial_key].should == 'value'
      end
    end

    context "and there is an old-style config" do
      let(:config) { project_fixture_config('old_api_key') }

      it "should fill the push_api_key with the old style key" do
        subject[:push_api_key].should == 'def'
      end

      it "should fill ignore_errors with the old style ignore exceptions" do
        subject[:ignore_errors].should == ['StandardError']
      end
    end
  end

  context "when there is a config file without the current env" do
    let(:config) { project_fixture_config('nonsense') }

    it "should log an error" do
      Appsignal::Config.any_instance.should_receive(:carefully_log_error).with(
        "Not loading from config file: config for 'nonsense' not found"
      ).once
      Appsignal::Config.any_instance.should_receive(:carefully_log_error).with(
        "Push api key not set after loading config"
      ).once
      subject
    end

    its(:valid?)  { should be_false }
    its(:active?) { should be_false }
  end

  context "when there is no config file" do
    let(:initial_config) { {} }
    let(:config) { Appsignal::Config.new('/nothing', 'production', initial_config) }

    its(:valid?)  { should be_false }
    its(:active?) { should be_false }

    context "with valid config in the environment" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY']   = 'aaa-bbb-ccc'
        ENV['APPSIGNAL_ACTIVE']         = 'true'
        ENV['APPSIGNAL_APP_NAME']       = 'App name'
        ENV['APPSIGNAL_DEBUG']          = 'true'
        ENV['APPSIGNAL_IGNORE_ACTIONS'] = 'action1,action2'
      end

      its(:valid?)  { should be_true }
      its(:active?) { should be_true }

      its([:push_api_key])   { should == 'aaa-bbb-ccc' }
      its([:active])         { should == true }
      its([:name])           { should == 'App name' }
      its([:debug])          { should == true }
      its([:ignore_actions]) { should == ['action1', 'action2'] }
    end
  end
end
