require 'spec_helper'
require 'appsignal/cli'

begin
  require 'sinatra'
rescue LoadError
end

describe Appsignal::CLI::Install do
  let(:out_stream) { StringIO.new }
  let(:cli) { Appsignal::CLI::Install }
  let(:config) { Appsignal::Config.new(nil, {}) }
  let(:auth_check) { double }

  before do
    Dir.stub(:pwd => project_fixture_path)
    @original_stdout = $stdout
    $stdout = out_stream
    Appsignal::AuthCheck.stub(:new => auth_check)
    auth_check.stub(:perform => '200')
    cli.stub(:sleep)
    cli.stub(:press_any_key)
  end
  after do
    $stdout = @original_stdout
  end

  describe ".run" do
    it "should not continue if there is no key" do
      cli.run(nil, config)

      out_stream.string.should include('Problem encountered:')
      out_stream.string.should include('No push API key entered')
    end

    context "auth check" do
      it "should exit if the key is invalid" do
        auth_check.stub(:perform => '402')

        cli.run('key', config)

        out_stream.string.should include("API key 'key' is not valid")
      end

      it "should exit if there was an error" do
        auth_check.stub(:perform).and_raise(StandardError.new)

        cli.run('key', config)

        out_stream.string.should include("There was an error validating your API key")
      end
    end
  end

  context "with rails" do
    if rails_present?
      describe ".run" do
        it "should install with environment variables" do
          cli.should_receive(:gets).once.and_return('n')
          cli.should_receive(:gets).once.and_return('2')

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Ruby on Rails")
          out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with config file" do
          cli.should_receive(:gets).once.and_return('n')
          cli.should_receive(:gets).once.and_return('1')
          cli.should_receive(:write_config_file)

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Ruby on Rails")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with an overridden app name and environment variables" do
          cli.should_receive(:gets).once.and_return('y')
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('2')

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Ruby on Rails")
          out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
          out_stream.string.should include("export APPSIGNAL_APP_NAME=Appname")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with an overridden app name and a config file" do
          cli.should_receive(:gets).once.and_return('y')
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('1')
          cli.should_receive(:write_config_file)

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Ruby on Rails")
          out_stream.string.should include("AppSignal installation complete")
        end
      end

      describe ".rails_environments" do
        before do
          Dir.stub(:pwd => project_fixture_path)
        end

        subject { cli.rails_environments }

        it { should == ['development', 'production'] }
      end

      describe ".installed_frameworks" do
        subject { cli.installed_frameworks }

        it { should include(:rails) }
      end
    end
  end

  context "with sinatra" do
    if sinatra_present? && !padrino_present? && !rails_present?
      describe ".install" do
        it "should install with environment variables" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('2')

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Sinatra")
          out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with a config file" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('1')
          cli.should_receive(:write_config_file)

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Sinatra")
          out_stream.string.should include("AppSignal installation complete")
        end
      end

      describe ".installed_frameworks" do
        subject { cli.installed_frameworks }

        it { should include(:sinatra) }
      end
    end
  end

  context "with padrino" do
    if padrino_present?
      describe ".install" do
        it "should install with environment variables" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('2')

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Padrino")
          out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with a config file" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('1')
          cli.should_receive(:write_config_file)

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Padrino")
          out_stream.string.should include("AppSignal installation complete")
        end
      end

      describe ".installed_frameworks" do
        subject { cli.installed_frameworks }

        it { should include(:padrino) }
      end
    end
  end

  context "with grape" do
    if grape_present?
      describe ".install" do
        it "should install with environment variables" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('2')

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Grape")
          out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
          out_stream.string.should include("AppSignal installation complete")
        end

        it "should install with a config file" do
          cli.should_receive(:gets).once.and_return('Appname')
          cli.should_receive(:gets).once.and_return('1')
          cli.should_receive(:write_config_file)

          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("Installing for Grape")
          out_stream.string.should include("AppSignal installation complete")
        end
      end

      describe ".installed_frameworks" do
        subject { cli.installed_frameworks }

        it { should include(:grape) }
      end
    end
  end

  context "with unknown framework" do
    if !rails_present? && !sinatra_present? && !padrino_present? && !grape_present?
      describe ".install" do
        it "should give a message about unknown framework" do
          cli.run('key', config)

          out_stream.string.should include("Validating API key...")
          out_stream.string.should include("API key valid")
          out_stream.string.should include("We could not detect which framework you are using.")
        end
      end

      describe ".installed_frameworks" do
        subject { cli.installed_frameworks }

        it { should be_empty }
      end
    end
  end

  describe ".colorize" do
    subject { cli.colorize('text', :green) }

    context "on windows" do
      before do
        Gem.stub(:win_platform? => true)
      end

      it { should == 'text' }
    end

    context "not on windows" do
      before do
        Gem.stub(:win_platform? => false)
      end

      it { should == "\e[32mtext\e[0m" }
    end
  end

  describe ".periods" do
    it "should output three periods" do
      cli.periods
      out_stream.string.should include('...')
    end
  end

  describe ".press_any_key" do
    before do
      cli.unstub(:press_any_key)
      STDIN.stub(:getch)
    end

    it "should continue" do
      cli.press_any_key
      out_stream.string.should include('Press any key')
    end
  end

  describe ".yes_or_no" do
    it "should take yes for an answer" do
      cli.should_receive(:gets).once.and_return('')
      cli.should_receive(:gets).once.and_return('nonsense')
      cli.should_receive(:gets).once.and_return('y')

      cli.yes_or_no('yes or no?: ').should be_true
    end

    it "should take no for an answer" do
      cli.should_receive(:gets).once.and_return('')
      cli.should_receive(:gets).once.and_return('nonsense')
      cli.should_receive(:gets).once.and_return('n')

      cli.yes_or_no('yes or no?: ').should be_false
    end
  end

  describe ".required_input" do
    it "should collect required input" do
      cli.should_receive(:gets).once.and_return('')
      cli.should_receive(:gets).once.and_return('value')

      cli.required_input('provide: ').should == 'value'
    end
  end

  describe ".configure" do
    before do
      config[:push_api_key] = 'key'
      config[:name] = 'Appname'
    end

    context "environment variables" do
      it "should output the environment variables" do
        cli.should_receive(:gets).once.and_return('2')

        cli.configure(config, [], false)

        out_stream.string.should include("Add the following environment variables to configure AppSignal")
        out_stream.string.should include("export APPSIGNAL_ACTIVE=true")
        out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
      end

      it "should output the environment variables with name overwritten" do
        cli.should_receive(:gets).once.and_return('2')

        cli.configure(config, [], true)

        out_stream.string.should include("Add the following environment variables to configure AppSignal")
        out_stream.string.should include("export APPSIGNAL_ACTIVE=true")
        out_stream.string.should include("export APPSIGNAL_PUSH_API_KEY=key")
        out_stream.string.should include("export APPSIGNAL_APP_NAME=Appname")
      end
    end

    context "config file" do
      it "should write the config file" do
        cli.should_receive(:gets).once.and_return('1')

        cli.should_receive(:write_config_file).with(
          :push_api_key => 'key',
          :app_name => config[:name],
          :environments => []
        )

        cli.configure(config, [], false)

        out_stream.string.should include("Writing config file")
        out_stream.string.should include("Config file written to config/appsignal.yml")
      end
    end

    context "when deploy.rb is present" do
      let(:config_dir) { File.join(tmp_dir, 'config') }
      let(:deploy_rb_file) { File.join(tmp_dir, 'config/deploy.rb') }
      before do
        Dir.stub(:pwd => tmp_dir)
        FileUtils.mkdir_p(config_dir)
        FileUtils.touch(deploy_rb_file)
        cli.should_receive(:gets).once.and_return('2')
      end
      after do
        FileUtils.rm_rf(config_dir)
      end

      it "should add a require to deploy.rb" do
        cli.configure(config, [], false)

        out_stream.string.should include 'Adding AppSignal integration to deploy.rb'
        File.read(deploy_rb_file).should include "require 'appsignal/capistrano'"
      end
    end
  end

  describe ".done_notice" do
    subject { out_stream.string }

    context "on windows" do
      before do
        Gem.stub(:win_platform? => true)
        cli.done_notice
      end

      it { should include('The AppSignal agent currently does not work on Windows') }
      it { should include('test/staging/production environment') }
    end

    context "not on windows" do
      before do
        Gem.stub(:win_platform? => false)
        cli.done_notice
      end

      it { should include('You can do this on your dev environment') }
      it { should include('Or deploy to staging or production') }
    end
  end

  context ".write_config_file" do
    before do
      Dir.stub(:pwd => tmp_dir)
    end

    it "should write a config file with environments" do
      cli.write_config_file(
        :push_api_key => 'key',
        :app_name => 'App name',
        :environments => [:staging, :production]
      )

      config = File.read(File.join(tmp_dir, 'config/appsignal.yml'))

      config.should include('name: "App name"')
      config.should include('push_api_key: "key"')
      config.should include('staging:')
      config.should include('production:')
    end

    it "should write a config file without environments" do
      cli.write_config_file(
        :push_api_key => 'key',
        :app_name => 'App name',
        :environments => []
      )

      config = File.read(File.join(tmp_dir, 'config/appsignal.yml'))

      config.should include('name: "App name"')
      config.should include('push_api_key: "key"')
      config.should_not include('staging:')
      config.should_not include('production:')
    end
  end
end
