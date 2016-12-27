require "rbconfig"
require "bundler/cli"
require "bundler/cli/common"
require "etc"

module Appsignal
  class CLI
    class Diagnose
      class << self
        def run(options = {})
          header
          empty_line

          agent_version
          empty_line

          host_information
          empty_line

          start_appsignal(options)

          config
          empty_line

          check_api_key
          empty_line

          paths_writable
          empty_line

          log_files
        end

        private

        def start_appsignal(options)
          current_path = Dir.pwd
          initial_config = {}
          if rails_app?
            current_path = Rails.root
            initial_config[:name] = Rails.application.class.parent_name
            initial_config[:log_path] = Rails.root.join("log")
          end

          ENV["APPSIGNAL_DIAGNOSE"] = "true"
          Appsignal.config = Appsignal::Config.new(
            current_path,
            options[:environment],
            initial_config
          )
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
          print "  Extension loaded: "
          puts Appsignal.extension_loaded ? "yes" : "no"
        end

        def host_information
          rbconfig = RbConfig::CONFIG
          puts "Host information"
          puts "  Architecture: #{rbconfig["host_cpu"]}"
          puts "  Operating System: #{rbconfig["host_os"]}"
          puts "  Ruby version: #{rbconfig["RUBY_VERSION_NAME"]}"
          puts "  Heroku: true" if Appsignal::System.heroku?
          print "  root user: "
          puts Process.uid == 0 ? "yes (not recommended)" : "no"
          if Appsignal::System.container?
            puts "  Container id: #{Appsignal::System::Container.id}"
          end
        end

        def config
          puts "Configuration"
          environment

          Appsignal.config.config_hash.each do |key, value|
            puts "  #{key}: #{value}"
          end
        end

        def environment
          env = Appsignal.config.env
          puts "  Environment: #{env}"
          if env == ""
            puts "    Warning: No environment set, no config loaded!"
            puts "    Please make sure appsignal diagnose is run within your "
            puts "    project directory with an environment."
            puts "      appsignal diagnose --environment=production"
          end
        end

        def paths_writable
          puts "Required paths"

          appsignal_paths.each do |name, path|
            puts "  #{name}: #{path.to_s.inspect}"
            unless path
              puts "    - Configured?: no"
              next
            end
            unless File.exist? path
              puts "    - Exists?: no"
              next
            end

            print "    - Writable?: "
            puts File.writable?(path) ? "yes" : "no"

            ownership = path_ownership(path)
            process_owner = ownership[:process]
            file_owner = ownership[:file]
            print "    - Ownership?: "
            owned = process_owner[:uid] == file_owner[:uid]
            print owned ? "yes" : "no"
            print " (file: #{file_owner[:name]}:#{file_owner[:uid]}, "
            puts "process: #{process_owner[:name]}:#{process_owner[:uid]})"
          end
        end

        def path_ownership(path)
          process_uid = Process.uid
          file_uid = File.stat(path).uid
          {
            :process => {
              :uid => process_uid,
              :name => Etc.getpwuid(process_uid).name
            },
            :file => {
              :uid => file_uid,
              :name => Etc.getpwuid(file_uid).name
            }
          }
        end

        def appsignal_paths
          config = Appsignal.config
          log_file_path = config.log_file_path
          {
            :current_path => Dir.pwd,
            :root_path => config.root_path,
            :log_dir_path => log_file_path ? File.dirname(log_file_path) : "",
            :log_file_path => log_file_path
          }
        end

        def check_api_key
          auth_check = ::Appsignal::AuthCheck.new(Appsignal.config, Appsignal.logger)
          print "Validating API key: "
          status, error = auth_check.perform_with_result
          case status
          when "200"
            print "Valid"
          when "401"
            print "Invalid"
          else
            print "Failed with status #{status}\n"
            puts error if error
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

        def empty_line
          puts "\n"
        end

        def rails_app?
          require "rails"
          require File.expand_path(File.join(Dir.pwd, "config", "application.rb"))
          true
        rescue LoadError
          false
        end

        def gem_path
          @gem_path ||= \
            Bundler::CLI::Common.select_spec("appsignal").full_gem_path.strip
        end
      end
    end
  end
end
