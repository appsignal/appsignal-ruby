# frozen_string_literal: true

require "rbconfig"
require "bundler/cli"
require "bundler/cli/common"
require "etc"
require "appsignal/cli/diagnose/utils"
require "appsignal/cli/diagnose/paths"

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
    # @example Automatically send the diagnose report without prompting
    #   appsignal diagnose --send-report
    #
    # @example Don't prompt about sending the report and don't sent it
    #   appsignal diagnose --no-send-report
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
          print_empty_line

          library_information
          print_empty_line

          host_information
          print_empty_line

          configure_appsignal(options)
          run_agent_diagnose_mode
          print_empty_line

          print_config_section
          print_empty_line

          check_api_key
          print_empty_line

          data[:process] = process_user

          paths_report = Paths.new
          data[:paths] = paths_report.report
          print_paths_section(paths_report)
          print_empty_line

          transmit_report_to_appsignal if send_report_to_appsignal?(options)
        end

        private

        def send_report_to_appsignal?(options)
          puts "\nDiagnostics report"
          puts "  Do you want to send this diagnostics report to AppSignal?"
          puts "  If you share this diagnostics report you will be given\n" \
            "  a support token you can use to refer to your diagnotics \n" \
            "  report when you contact us at support@appsignal.com\n\n"
          send_diagnostics =
            if options.key?(:send_report)
              if options[:send_report]
                puts "  Confirmed sending report using --send-report option."
                true
              else
                puts "  Not sending report. (Specified with the --no-send-report option.)"
                false
              end
            else
              yes_or_no(
                "  Send diagnostics report to AppSignal? (Y/n): ",
                :default => "y"
              )
            end
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

          puts "  Please email us at support@appsignal.com with the following"
          puts "  support token."
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
          Appsignal.start_logger
          Appsignal.logger.info("Starting AppSignal diagnose")
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

          agent_diagnostic_test_definition.each do |component, component_definition|
            puts "  #{component_definition[:label]}"
            component_definition[:tests].each do |category, tests|
              tests.each do |test_name, test_definition|
                test_report = report
                  .fetch(component, {})
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

          print "    #{definition[:label]}: "
          display_value =
            definition[:values] ? definition[:values][value] : value
          print display_value.nil? ? "-" : display_value
          print "\n      Error: #{error}" if error
          print "\n      Output: #{output}" if output
          print "\n"
        end

        def agent_diagnostic_test_definition
          {
            "extension" => {
              :label => "Extension tests",
              :tests => {
                "config" => {
                  "valid" => {
                    :label => "Configuration",
                    :values => { true => "valid", false => "invalid" }
                  }
                }
              }
            },
            "agent" => {
              :label => "Agent tests",
              :tests => {
                "boot" => {
                  "started" => {
                    :label => "Started",
                    :values => { true => "started", false => "not started" }
                  }
                },
                "host" => {
                  "uid" => { :label => "Process user id" },
                  "gid" => { :label => "Process user group id" }
                },
                "config" => {
                  "valid" => {
                    :label => "Configuration",
                    :values => { true => "valid", false => "invalid" }
                  }
                },
                "logger" => {
                  "started" => {
                    :label => "Logger",
                    :values => { true => "started", false => "not started" }
                  }
                },
                "working_directory_stat" => {
                  "uid" => { :label => "Working directory user id" },
                  "gid" => { :label => "Working directory user group id" },
                  "mode" => { :label => "Working directory permissions" }
                },
                "lock_path" => {
                  "created" => {
                    :label => "Lock path",
                    :values => { true => "writable", false => "not writable" }
                  }
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
            puts_and_save :agent_architecture, "Agent architecture",
              Appsignal::System.installed_agent_architecture
            puts_and_save :extension_loaded, "Extension loaded", Appsignal.extension_loaded
          end
        end

        def host_information
          rbconfig = RbConfig::CONFIG
          puts "Host information"
          data_section :host do
            puts_and_save :architecture, "Architecture", rbconfig["host_cpu"]

            os_label = os = rbconfig["host_os"]
            os_label = "#{os} (Microsoft Windows is not supported.)" if Gem.win_platform?
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

        def print_config_section
          puts "Configuration"
          config = Appsignal.config
          data[:config] = {
            :config => config.config_hash.merge(:env => config.env),
            :sources => {
              :default => Appsignal::Config::DEFAULT_CONFIG,
              :system => config.system_config,
              :initial => config.initial_config,
              :file => config.file_config,
              :env => config.env_config
            }
          }
          print_environment(config)
          print_config_options(config)
        end

        def print_environment(config)
          env = config.env
          puts_value "Environment", env

          return unless env == ""
          puts "    Warning: No environment set, no config loaded!"
          puts "    Please make sure appsignal diagnose is run within your "
          puts "    project directory with an environment."
          puts "      appsignal diagnose --environment=production"
        end

        def print_config_options(config)
          config.config_hash.each do |key, value|
            puts "  #{key}: #{value}"
          end
        end

        def process_user
          return @process_user if defined?(@process_user)

          process_uid = Process.uid
          @process_user = {
            :uid => process_uid,
            :user => Utils.username_for_uid(process_uid)
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

        def print_paths_section(report)
          puts "Paths"
          report_paths = report.paths
          data[:paths].each do |name, file|
            print_path_details report_paths[name][:label], file
          end
        end

        def print_path_details(name, path)
          puts "  #{name}"
          puts_value "Path", path[:path].to_s.inspect, :level => 2

          unless path[:exists]
            puts_value "Exists?", path[:exists], :level => 2
            return
          end

          puts_value "Writable?", path[:writable], :level => 2

          ownership = path[:ownership]
          owned = process_user[:uid] == ownership[:uid]
          owner = "#{owned} " \
            "(file: #{ownership[:user]}:#{ownership[:uid]}, " \
            "process: #{process_user[:user]}:#{process_user[:uid]})"
          puts_value "Ownership?", owner, :level => 2
          return unless path.key?(:content)
          puts "    Contents (last 10 lines):"
          puts path[:content][0..10]
        end

        def print_empty_line
          puts "\n"
        end

        def rails_app?
          require "rails"
          require File.expand_path(File.join(Dir.pwd, "config", "application.rb"))
          true
        rescue LoadError
          false
        end
      end
    end
  end
end
