require 'spec_helper'

if rails_present?
  require 'generator_spec/test_case'
  require './lib/generators/appsignal/appsignal_generator'

  # The generator doesn't know we're testing
  # So change the path while running the generator
  # Change it back upon completion
  def run_generator_in_tmp(args=[])
    FileUtils.cd(tmp_dir) do
      FileUtils.mkdir_p('config/environments')
      FileUtils.touch('config/environments/development.rb')
      FileUtils.touch('config/environments/production.rb')
      @output = run_generator(args)
    end
  end

  describe AppsignalGenerator do
    include GeneratorSpec::TestCase
    destination tmp_dir

    let(:authcheck) { Appsignal::AuthCheck.new(nil, nil) }
    let(:err_stream) { StringIO.new }

    before do
      Appsignal::AuthCheck.stub(:new => authcheck)
      FileUtils.rm_rf(tmp_dir)
      @original_stderr = $stderr
      $stderr = err_stream
    end
    after do
      $stderr = @original_stderr
    end

    context "with key" do
      context "known key" do
        before do
          authcheck.should_receive(:perform).and_return('200')

          prepare_destination
          run_generator_in_tmp %w(my_app_key)
        end

        it "should generate a correct config file" do
          fixture_config_file = File.open(File.join(fixtures_dir, 'generated_config.yml')).read
          generated_config_file = File.open(File.join(tmp_dir, 'config/appsignal.yml')).read

          generated_config_file.should == fixture_config_file
        end

        it "should mention successful auth check" do
          @output.should include('success')
          @output.should include('AppSignal has confirmed authorization!')
        end
      end

      context "invalid key" do
        before do
          authcheck.should_receive(:perform).and_return('401')

          prepare_destination
          run_generator_in_tmp %w(my_app_key)
        end

        it "should mention invalid key" do
          @output.should include('error')
          @output.should include('API key not valid with AppSignal...')
        end
      end

      context "failed check" do
        before do
          authcheck.should_receive(:perform).and_return('500')

          prepare_destination
          run_generator_in_tmp %w(my_app_key)
        end

        it "should mention failed check" do
          @output.should include('error')
          @output.should include('Could not confirm authorization')
        end
      end

      context "internal failure" do
        before do
          authcheck.stub(:perform).and_throw(:error)

          prepare_destination
          run_generator_in_tmp %w(my_app_key)
        end

        it "should mention internal failure" do
          @output.should include(
            'Something went wrong while trying to '\
            'authenticate with AppSignal:'
          )
        end
      end
    end

    context "without key" do
      before do
        prepare_destination
        run_generator_in_tmp %w()
      end

      it "should not create a config file" do
        destination_root.should have_structure {
          directory 'config' do
            no_file 'appsignal.yml'
            no_file 'deploy.rb'
          end
        }
        err_stream.string.should include "No value provided for required arguments 'push_api_key'"
      end
    end

    context "without capistrano" do
      before do
        prepare_destination
        authcheck.stub(:perform).and_return(['200', 'everything ok'])
        run_generator_in_tmp %w(my_app_key)
      end

      it "should create a config file" do
        destination_root.should have_structure {
          directory 'config' do
            file 'appsignal.yml'
            no_file 'deploy.rb'
          end
        }
      end

      it "should mention the deploy task" do
        @output.should include('No capistrano setup detected!')
        @output.should include('appsignal notify_of_deploy -h')
      end
    end

    context "with capistrano" do
      before do
        cap_file = File.join(destination_root, 'Capfile')
        deploy_file = File.join(destination_root, 'config', 'deploy.rb')

        prepare_destination
        File.open(cap_file, 'w') {}
        FileUtils.mkdir(File.join(destination_root, 'config'))
        File.open(deploy_file, 'w') {}
        authcheck.stub(:perform).and_return(['200', 'everything ok'])
        run_generator_in_tmp %w(my_app_key)
      end

      it "should create a config file and modify the capistrano deploy file" do
        destination_root.should have_structure {
          file 'Capfile'
          directory 'config' do
            file 'appsignal.yml'
            file 'deploy.rb' do
              contains "require 'appsignal/capistrano'"
            end
          end
        }
      end

      it "should not mention the deploy task" do
        @output.should_not include('No capistrano setup detected!')
        @output.should_not include('appsignal notify_of_deploy -h')
      end
    end
  end
end
