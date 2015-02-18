require 'spec_helper'

describe Appsignal::Config do
  subject { config }

  describe "when there is a config file" do
    let(:config) { project_fixture_config('production') }

    it "should not log an error" do
      Appsignal::Config.any_instance.should_not_receive(:carefully_log_error)
      subject
    end

    its(:loaded?) { should be_true }
    its(:active?) { should be_true }

    it "should merge with the default config and fill the config hash" do
      subject.config_hash.should == {
        :ignore_exceptions              => [],
        :ignore_actions                 => [],
        :instrument_net_http            => true,
        :skip_session_data              => false,
        :send_params                    => true,
        :endpoint                       => 'https://push.appsignal.com/1',
        :slow_request_threshold         => 200,
        :push_api_key                   => 'abc',
        :name                           => 'TestApp',
        :active                         => true,
        :enable_frontend_error_catching => false,
        :frontend_error_catching_path   => '/appsignal_error_catcher'
      }
    end

    describe "#[]" do
      it "should get the value for an existing key" do
        subject[:push_api_key].should == 'abc'
      end

      it "should return nil for a non-existing key" do
        subject[:nonsense].should be_nil
      end
    end

    context "if the env is passed as a symbol" do
      let(:config) { project_fixture_config(:production) }

      its(:active?) { should be_true }
    end

    context "and there's also an env var present" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY'] = 'push_api_key'
      end

      it "should ignore the env var" do
        subject[:push_api_key].should == 'abc'
      end
    end

    context "and there is an initial config" do
      let(:config) { project_fixture_config('production', :name => 'Initial name', :initial_key => 'value') }

      it "should merge with the config" do
        subject[:name].should == 'TestApp'
        subject[:initial_key].should == 'value'
      end
    end

    context "and there is an old-style api_key defined" do
      let(:config) { project_fixture_config('old_api_key') }

      it "should fill the push_api_key with the old style key" do
        subject[:push_api_key].should == 'def'
      end
    end
  end

  context "when there is a config file without the current env" do
    let(:config) { project_fixture_config('nonsense') }

    it "should log an error" do
      Appsignal::Config.any_instance.should_receive(:carefully_log_error).with(
        "Not loading: config for 'nonsense' not found"
      )
      subject
    end

    its(:loaded?) { should be_false }
    its(:active?) { should be_false }
  end

  context "when there is no config file" do
    let(:initial_config) { {} }
    let(:config) { Appsignal::Config.new('/nothing', 'production', initial_config) }

    it "should log an error" do
      Appsignal::Config.any_instance.should_receive(:carefully_log_error).with(
        "Not loading: No config file found at '/nothing/config/appsignal.yml' " \
        "and no APPSIGNAL_PUSH_API_KEY env var present"
      )
      subject
    end

    its(:loaded?) { should be_false }
    its(:active?) { should be_false }

    describe "#[]" do
      it "should return nil" do
        subject[:endpoint].should be_nil
      end
    end

    context "and an env var is present" do
      before do
        ENV['APPSIGNAL_PUSH_API_KEY'] = 'push_api_key'
      end

      it "should not log an error" do
        Appsignal::Config.any_instance.should_not_receive(:carefully_log_error)
        subject
      end

      its(:loaded?) { should be_true }
      its(:active?) { should be_true }

      it "should merge with the default config, fill the config hash and log about the missing name" do
        Appsignal.logger.should_receive(:debug).with(
          "There's no application name set in your config file or in the APPSIGNAL_APP_NAME env var. You should set one unless your app runs on Heroku."
        )

        subject.config_hash.should == {
          :push_api_key                   => 'push_api_key',
          :ignore_exceptions              => [],
          :ignore_actions                 => [],
          :send_params                    => true,
          :instrument_net_http            => true,
          :skip_session_data              => false,
          :endpoint                       => 'https://push.appsignal.com/1',
          :slow_request_threshold         => 200,
          :active                         => true,
          :enable_frontend_error_catching => false,
          :frontend_error_catching_path   => '/appsignal_error_catcher'
        }
      end

      context "and an initial config with a name is present" do
        let(:initial_config) { {:name => 'Initial Name'} }

        it "should merge with the config" do
          Appsignal.logger.should_not_receive(:debug)
          subject[:name].should == 'Initial Name'
        end
      end

      context "more config in environment" do
        context "APPSIGNAL_APP_NAME is set" do
          before do
            ENV['APPSIGNAL_APP_NAME'] = 'Name from env'
          end

          it "should set the name" do
            Appsignal.logger.should_not_receive(:debug)
            subject[:name].should == 'Name from env'
          end
        end

        context "APPSIGNAL_ACTIVE" do
          context "not present" do
            before do
              ENV.delete('APPSIGNAL_ACTIVE')
            end

            it "should still set active to true" do
              subject[:active].should be_true
            end
          end

          context "true" do
            before do
              ENV['APPSIGNAL_ACTIVE'] = 'true'
            end

            it "should set active to true" do
              subject[:active].should be_true
            end
          end

          context "false" do
            before do
              ENV['APPSIGNAL_ACTIVE'] = 'false'
            end

            it "should set active to false" do
              subject[:active].should be_false
            end
          end
        end
      end

      context "with only APPSIGNAL_API_KEY" do
        before do
          ENV.delete('APPSIGNAL_PUSH_API_KEY')
          ENV['APPSIGNAL_API_KEY'] = 'old_style_api_key'
        end

        it "should use the old style api key" do
          subject[:push_api_key].should == 'old_style_api_key'
        end
      end

      context "with both APPSIGNAL_PUSH_API_KEY and APPSIGNAL_API_KEY" do
        before do
          ENV['APPSIGNAL_API_KEY'] = 'old_style_api_key'
        end

        it "should use the new style push api key" do
          subject[:push_api_key].should == 'push_api_key'
        end
      end
    end
  end
end
