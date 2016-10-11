require "rbconfig"
require "bundler/cli"
require "bundler/cli/common"

module Appsignal
  class CLI
    class Diagnose
      class << self
        def run
          header
          empty_line

          agent_version
          empty_line

          host_information
          empty_line

          start_appsignal
          config
          empty_line

          check_api_key
          empty_line

          paths_writable
          empty_line

          log_files
        end

        private

        def empty_line
          puts "\n"
        end

        def start_appsignal
          Appsignal.start
        end

        def header
          puts "AppSignal diagnose"
          puts "=" * 80
          puts "Use this information to debug your configuration."
          puts "More information is available on the documentation site."
          puts "http://docs.appsignal.com/"
          puts "Send this output to support@appsignal.com if you need help."
          puts "=" * 80
        end

        def agent_version
          puts "AppSignal agent"
          puts "  Gem version: #{Appsignal::VERSION}"
          puts "  Agent version: #{Appsignal::Extension.agent_version}"
          puts "  Gem install path: #{gem_path}"
        end

        def host_information
          rbconfig = RbConfig::CONFIG
          puts "Host information"
          puts "  Architecture: #{rbconfig["host_cpu"]}"
          puts "  Operating System: #{rbconfig["host_os"]}"
          puts "  Ruby version: #{rbconfig["RUBY_VERSION_NAME"]}"
        end

        def environment
          env = Appsignal.config.env
          puts "  Environment: #{env}"
          if env == ""
            puts "    Warning: No environment set, no config loaded!"
            puts "    Please make sure appsignal diagnose is run within your "
            puts "    project directory with an environment."
            puts "      APPSIGNAL_APP_ENV=production appsignal diagnose"
          end
        end

        def config
          puts "Configuration"
          environment
          Appsignal.config.config_hash.each do |key, value|
            puts "  #{key}: #{value}"
          end
        end

        def paths_writable
          possible_paths = {
            :root_path => Appsignal.config.root_path,
            :log_file_path => Appsignal.config.log_file_path
          }

          puts "Required paths"
          possible_paths.each do |name, path|
            result = "Not writable"
            if path
              if !File.exist? path
                result = "Does not exist"
              elsif File.writable? path
                result = "Writable"
              end
            end
            puts "  #{name}: #{path.to_s.inspect} - #{result}"
          end
        end

        def check_api_key
          auth_check = ::Appsignal::AuthCheck.new(Appsignal.config, Appsignal.logger)
          print "Validating API key: "
          status, _ = auth_check.perform_with_result
          case status
          when "200"
            print "Valid"
          when "401"
            print "Invalid"
          else
            print "Failed with status #{status}"
          end
          empty_line
        end

        def log_files
          install_log
          empty_line
          mkmf_log
        end

        def install_log
          install_log_path = File.join(gem_path, "ext", "install.log")
          puts "Extension install log"
          output_log_file install_log_path
        end

        def mkmf_log
          mkmf_log_path = File.join(gem_path, "ext", "mkmf.log")
          puts "Makefile install log"
          output_log_file mkmf_log_path
        end

        def output_log_file(log_file)
          puts "  Path: #{log_file.to_s.inspect}"
          if File.exist? log_file
            puts "  Contents:"
            puts File.read(log_file)
          else
            puts "  File not found."
          end
        end

        def gem_path
          @gem_path ||= \
            Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip
        end
      end
    end
  end
end
