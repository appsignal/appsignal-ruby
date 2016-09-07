module Appsignal
  class CLI
    class Diagnose
      class << self
        def run
          gem_version
          agent_version
          start_appsignal
          config
          check_api_key
          paths_writable
          check_ext_install
        end

        def gem_version
          puts "Gem version: #{Appsignal::VERSION}"
        end

        def agent_version
          puts "Agent version: #{Appsignal::Extension.agent_version}"
        end

        def start_appsignal
          Appsignal.start
        end

        def config
          start_appsignal
          puts "Environment: #{Appsignal.config.env}"
          Appsignal.config.config_hash.each do |key, val|
            puts "Config #{key}: #{val}"
          end
        end

        def paths_writable
          start_appsignal
          possible_paths = [
            Appsignal.config.root_path,
            Appsignal.config.log_file_path
          ]

          puts "Checking if required paths are writable:"
          possible_paths.each do |path|
            result = File.writable?(path) ? 'Ok' : 'Failed'
            puts "#{path} ...#{result}"
          end
          puts "\n"
        end

        def check_api_key
          start_appsignal
          auth_check = ::Appsignal::AuthCheck.new(Appsignal.config, Appsignal.logger)
          status, _ = auth_check.perform_with_result
          if status == '200'
            puts "Checking API key: Ok"
          else
            puts "Checking API key: Failed"
          end
        end

        def check_ext_install
          require 'bundler/cli'
          require "bundler/cli/common"
          path     = Bundler::CLI::Common.select_spec('appsignal').full_gem_path
          install_log_path = "#{path.strip}/ext/install.log"
          puts "Showing last lines of extension install log: #{install_log_path}"
          puts File.read(install_log_path)
          puts "\n"
          mkmf_log_path = "#{path.strip}/ext/mkmf.log"
          if File.exist?(mkmf_log_path)
            puts "Showing last lines of extension compilation log: #{mkmf_log_path}"
            puts File.read(mkmf_log_path)
            puts "\n"
          else
            puts "#{mkmf_log_path} not present"
          end
        end
      end
    end
  end
end
