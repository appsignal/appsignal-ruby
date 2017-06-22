require "rbconfig"
require "bundler/cli"
require "bundler/cli/common"
require "etc"

module Appsignal
  class CLI
    # Command line tool to run diagnostics on your project.
    #
    # This command line tool is useful when testing AppSignal on a system and
    # validating the local configuration. It outputs useful information to
    # debug issues and it checks if AppSignal agent is able to run on the
    # machine's architecture and communicate with the AppSignal servers.
    #
    # This diagnostic tool outputs the following:
    # - if AppSignal can run on the host system.
    # - if the configuration is valid and active.
    # - if the Push API key is present and valid (internet connection required).
    # - if the required system paths exist and are writable.
    # - outputs AppSignal version information.
    # - outputs information about the host system and Ruby.
    # - outputs last lines from the available log files.
    #
    # ## Exit codes
    #
    # - Exits with status code `0` if the diagnose command has finished.
    # - Exits with status code `1` if the diagnose command failed to finished.
    #
    # @example On the command line in your project
    #   appsignal diagnose
    #
    # @example With a specific environment
    #   appsignal diagnose --environment=production
    #
    # @see http://docs.appsignal.com/support/debugging.html Debugging AppSignal
    # @see http://docs.appsignal.com/ruby/command-line/diagnose.html
    #   AppSignal diagnose documentation
    # @since 1.1.0
    class Diagnose
      extend CLI::Helpers

      DIAGNOSE_ENDPOINT = "https://appsignal.com/diag".freeze

      module Data
        def data
          @data ||= Hash.new { |hash, key| hash[key] = {} }
        end

        def data_section(key)
          @section = key
          yield
          @section = nil
        end

        def current_section
          @section
        end

        def save(key, value)
          data[current_section][key] = value
        end
      end
      extend Data

      class << self
        # @param options [Hash]
        # @option options :environment [String] environment to load
        #   configuration for.
        # @return [void]
        # @api private
        def run(options = {})
          $stdout.sync = true
          header
          empty_line

          library_information
          empty_line

          host_information
          empty_line

          configure_appsignal(options)
          run_agent_diagnose_mode
          empty_line

          config
          empty_line

          check_api_key
          empty_line

          paths_section
          empty_line

          log_files

          transmit_report_to_appsignal if send_report_to_appsignal?
        end

        private

        def send_report_to_appsignal?
          puts "\nDiagnostics report"
          puts "  Do you want to send this diagnostics report to AppSignal?"
          puts "  If you share this diagnostics report you will be given\n" \
            "  a support token you can use to refer to your diagnotics \n" \
            "  report when you contact us at support@appsignal.com\n\n"
          send_diagnostics = yes_or_no(
            "  Send diagnostics report to AppSignal? (Y/n): ",
            :default => "y"
          )
          unless send_diagnostics
            puts "  Not sending diagnostics information to AppSignal."
            return false
          end
          true
        end

        def transmit_report_to_appsignal
          puts "\n  Transmitting diagnostics report"
          transmitter = Transmitter.new(
            DIAGNOSE_ENDPOINT,
            Appsignal.config
          )
          response = transmitter.transmit(:diagnose => data)

          unless response.code == "200"
            puts "  Error: Something went wrong while submitting the report "\
              "to AppSignal."
            puts "  Response code: #{response.code}"
            puts "  Response body:\n#{response.body}"
            return
          end

          puts "  Your diagnostics report has been sent to AppSignal."
          begin
            response_data = JSON.parse(response.body)
            puts "  Your support token: #{response_data["token"]}"
          rescue JSON::ParserError
            puts "  Error: Couldn't decode server response."
            puts "  #{response.body}"
          end
        end

        def puts_and_save(key, label, value)
          save key, value
          puts_value label, value
        end

        def puts_value(label, value, options = {})
          options[:level] ||= 1
          puts "#{"  " * options[:level]}#{label}: #{value}"
        end

        def configure_appsignal(options)
          current_path = Dir.pwd
          initial_config = {}
          if rails_app?
            data[:app][:rails] = true
            current_path = Rails.root
            initial_config[:name] = Rails.application.class.parent_name
            initial_config[:log_path] = current_path.join("log")
          end

          Appsignal.config = Appsignal::Config.new(
            current_path,
            options[:environment],
            initial_config
          )
          Appsignal.config.write_to_environment
        end

        def run_agent_diagnose_mode
          puts "Agent diagnostics"
          unless Appsignal.extension_loaded?
            puts "  Extension is not loaded. No agent report created."
            return
          end

          ENV["_APPSIGNAL_DIAGNOSE"] = "true"
          diagnostics_report_string = Appsignal::Extension.diagnose
          ENV.delete("_APPSIGNAL_DIAGNOSE")

          begin
            report = JSON.parse(diagnostics_report_string)
            data[:agent] = report
            print_agent_report(report)
          rescue JSON::ParserError => error
            puts "  Error while parsing agent diagnostics report:"
            puts "    Error: #{error}"
            puts "    Output: #{diagnostics_report_string}"
            data[:agent] = {
              :error => error,
              :output => diagnostics_report_string.split("\n")
            }
          end
        end

        def print_agent_report(report)
          if report["error"]
            puts "  Error: #{report["error"]}"
            return
          end

          agent_diagnostic_test_definition.each do |part, categories|
            categories.each do |category, tests|
              tests.each do |test_name, test_definition|
                test_report = report
                  .fetch(part, {})
                  .fetch(category, {})
                  .fetch(test_name, {})

                print_agent_test(test_definition, test_report)
              end
            end
          end
        end

        def print_agent_test(definition, test)
          value = test["result"]
          error = test["error"]
          output = test["output"]

          print "  #{definition[:label]}: "
          display_value = definition[:values][value]
          print display_value.nil? ? "-" : display_value
          print "\n    Error: #{error}" if error
          print "\n    Output: #{output}" if output
          print "\n"
        end

        def agent_diagnostic_test_definition
          {
            "extension" => {
              "config" => {
                "valid" => {
                  :label => "Extension config",
                  :values => { true => "valid", false => "invalid" }
                }
              }
            },
            "agent" => {
              "boot" => {
                "started" => {
                  :label => "Agent started",
                  :values => { true => "started", false => "not started" }
                }
              },
              "config" => {
                "valid" => {
                  :label => "Agent config",
                  :values => { true => "valid", false => "invalid" }
                }
              },
              "logger" => {
                "started" => {
                  :label => "Agent logger",
                  :values => { true => "started", false => "not started" }
                }
              },
              "lock_path" => {
                "created" => {
                  :label => "Agent lock path",
                  :values => { true => "writable", false => "not writable" }
                }
              }
            }
          }
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

        def library_information
          puts "AppSignal library"
          data_section :library do
            save :language, "ruby"
            puts_and_save :package_version, "Gem version", Appsignal::VERSION
            puts_and_save :agent_version, "Agent version", Appsignal::Extension.agent_version
            puts_and_save :package_install_path, "Gem install path", gem_path
            puts_and_save :extension_loaded, "Extension loaded", Appsignal.extension_loaded
          end
        end

        def host_information
          rbconfig = RbConfig::CONFIG
          puts "Host information"
          data_section :host do
            puts_and_save :architecture, "Architecture", rbconfig["host_cpu"]

            os_label = os = rbconfig["host_os"]
            os_label = "#{os_label} (Microsoft Windows is not supported.)" if Gem.win_platform?
            save :os, os
            puts_value "Operating System", os_label

            puts_and_save :language_version, "Ruby version",
              "#{rbconfig["ruby_version"]}-p#{rbconfig["PATCHLEVEL"]}"

            puts_value "Heroku", "true" if Appsignal::System.heroku?
            save :heroku, Appsignal::System.heroku?

            save :root, Process.uid.zero?
            puts_value "root user",
              Process.uid.zero? ? "true (not recommended)" : "false"
            puts_and_save :running_in_container, "Running in container",
              Appsignal::Extension.running_in_container?
          end
        end

        def config
          puts "Configuration"
          data_section :config do
            puts_environment

            Appsignal.config.config_hash.each do |key, value|
              puts_and_save key, key, value
            end
          end
        end

        def puts_environment
          env = Appsignal.config.env
          puts_and_save :env, "Environment", env

          return unless env == ""
          puts "    Warning: No environment set, no config loaded!"
          puts "    Please make sure appsignal diagnose is run within your "
          puts "    project directory with an environment."
          puts "      appsignal diagnose --environment=production"
        end

        def paths_section
          puts "Paths"
          data[:process] = process_user
          data_section :paths do
            appsignal_paths.each do |name, path|
              path_info = {
                :path => path,
                :configured => !path.nil?,
                :exists => false,
                :writable => false
              }
              save name, path_info

              puts_value name, path.to_s.inspect

              unless path_info[:configured]
                puts_value "Configured?", "false", :level => 2
                next
              end
              unless File.exist?(path)
                puts_value "Exists?", "false", :level => 2
                next
              end

              path_info[:exists] = true
              path_info[:writable] = File.writable?(path)
              puts_value "Writable?", path_info[:writable], :level => 2

              file_owner = path_ownership(path)
              path_info[:ownership] = file_owner
              save name, path_info

              owned = process_user[:uid] == file_owner[:uid]
              owner = "#{owned} " \
                "(file: #{file_owner[:user]}:#{file_owner[:uid]}, " \
                "process: #{process_user[:user]}:#{process_user[:uid]})"
              puts_value "Ownership?", owner, :level => 2
            end
          end
        end

        def path_ownership(path)
          file_uid = File.stat(path).uid
          {
            :uid => file_uid,
            :user => username_for_uid(file_uid)
          }
        end

        def process_user
          return @process_user if defined?(@process_user)

          process_uid = Process.uid
          @process_user = {
            :uid => process_uid,
            :user => username_for_uid(process_uid)
          }
        end

        def appsignal_paths
          config = Appsignal.config
          log_file_path = config.log_file_path
          {
            :working_dir => Dir.pwd,
            :root_path => config.root_path,
            :log_dir_path => log_file_path ? File.dirname(log_file_path) : "",
            :log_file_path => log_file_path
          }
        end

        def check_api_key
          puts "Validation"
          data_section :validation do
            auth_check = ::Appsignal::AuthCheck.new(Appsignal.config)
            status, error = auth_check.perform_with_result
            result =
              case status
              when "200"
                "valid"
              when "401"
                "invalid"
              else
                "Failed with status #{status}\n#{error.inspect}"
              end
            puts_and_save :push_api_key, "Validating Push API key", result
          end
        end

        def log_files
          puts "Log files"
          data_section :logs do
            install_log
            empty_line
            mkmf_log
          end
        end

        def install_log
          puts "  Extension install log"
          filename = File.join("ext", "install.log")
          log_info = log_file_info(File.join(gem_path, filename))
          save filename, log_info
          puts_log_file log_info
        end

        def mkmf_log
          puts "  Makefile install log"
          filename = File.join("ext", "mkmf.log")
          log_info = log_file_info(File.join(gem_path, filename))
          save filename, log_info
          puts_log_file log_info
        end

        def log_file_info(log_file)
          {
            :path => log_file,
            :exists => File.exist?(log_file)
          }.tap do |info|
            next unless info[:exists]
            info[:content] = File.read(log_file).split("\n")
          end
        end

        def puts_log_file(log_info)
          puts_value "Path", log_info[:path].to_s.inspect, :level => 2
          if log_info[:exists]
            puts "    Contents:"
            puts log_info[:content].join("\n")
          else
            puts "    File not found."
          end
        end

        def username_for_uid(uid)
          passwd_struct = Etc.getpwuid(uid)
          return unless passwd_struct
          passwd_struct.name
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
