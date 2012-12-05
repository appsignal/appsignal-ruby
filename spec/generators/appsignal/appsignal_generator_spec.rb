require 'spec_helper'
require "generator_spec/test_case"
require './lib/generators/appsignal/appsignal_generator'

# The generator doesn't know we're testing
# So change the path while running the generator
# Change it back upon completion
def run_generator_in_tmp(args=[])
  FileUtils.cd("spec/tmp") do
    run_generator args
  end
end

describe AppsignalGenerator do
  include GeneratorSpec::TestCase
  destination File.expand_path("../../../tmp", __FILE__)

  context "with key" do
    context "normal flow" do
      before do
        prepare_destination
        run_generator_in_tmp %w(my_app_key)
      end

      specify "config file is created" do
        destination_root.should have_structure {
          directory 'config' do
            file 'appsignal.yml' do
              contains 'production:'
              contains 'api_key: "my_app_key"'
            end
            no_file 'deploy.rb'
          end
        }
      end
    end

    context "with capistrano" do
      before do
        prepare_destination
        cap_file = File.expand_path('Capfile', destination_root)
        File.open(cap_file, 'w') {}
        FileUtils.mkdir(File.expand_path('config', destination_root))
        deploy_file = File.expand_path(File.join('config', 'deploy.rb'),
          destination_root)
        File.open(deploy_file, 'w') {}
        run_generator_in_tmp %w(my_app_key)
      end

      specify "config file is created and capistrano deploy file modified" do
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
    end
  end

  context "with custom environment" do
    context "normal flow" do
      before do
        prepare_destination
        run_generator_in_tmp %w(my_app_key --environment=development)
      end

      specify "config file is created" do
        destination_root.should have_structure {
          directory 'config' do
            file 'appsignal.yml' do
              contains 'development:'
              contains 'api_key: "my_app_key"'
            end
            no_file 'deploy.rb'
          end
        }
      end
    end
  end

  context "multiple environments" do
    context "normal flow" do
      context "with new environment" do
        before do
          prepare_destination
          FileUtils.mkdir(File.expand_path('config', destination_root))
          config_file = File.join('config', 'appsignal.yml')
          File.open(File.expand_path(config_file, destination_root), 'w') do |f|
            f.write("production:\n  api_key: 111")
          end
          run_generator_in_tmp %w(my_app_key --environment=development)
        end

        specify "config file is created" do
          destination_root.should have_structure {
            directory 'config' do
              file 'appsignal.yml' do
                contains 'production:'
                contains "\ndevelopment:"
                contains 'api_key: "my_app_key"'
              end
              no_file 'deploy.rb'
            end
          }
        end
      end

      context "with existing environment" do
        before do
          prepare_destination
          FileUtils.mkdir(File.expand_path('config', destination_root))
          config_file = File.join('config', 'appsignal.yml')
          File.open(File.expand_path(config_file, destination_root), 'w') do |f|
            f.write("development:\n  api_key: \"111\"")
          end
          run_generator_in_tmp %w(my_app_key --environment=development)
        end

        specify "config file is created" do
          destination_root.should have_structure {
            directory 'config' do
              file 'appsignal.yml' do
                contains "development:"
                contains 'api_key: "111"'
              end
              no_file 'deploy.rb'
            end
          }
        end
      end
    end
  end

  context "without key" do
    before do
      prepare_destination
      run_generator_in_tmp %w()
    end

    specify "no config files are created" do
      destination_root.should have_structure {
        directory 'config' do
          no_file 'appsignal.yml'
          no_file 'deploy.rb'
        end
      }
    end
  end
end
