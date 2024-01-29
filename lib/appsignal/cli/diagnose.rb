# frozen_string_literal: true

require "rbconfig"
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
    # @see https://docs.appsignal.com/support/debugging.html Debugging AppSignal
    # @see https://docs.appsignal.com/ruby/command-line/diagnose.html
    #   AppSignal diagnose documentation
    # @since 1.1.0
    class Diagnose
      extend CLI::Helpers

      DIAGNOSE_ENDPOINT = "https://appsignal.com/diag"

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
          self.coloring = options.delete(:color) { true }
          $stdout.sync = true
          header
          print_empty_line

          library_information
          data[:installation] = fetch_installation_report
          print_installation_report
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

          transmit_report_to_appsignal if send_report_to_appsignal?(options)
        end

        private

        def send_report_to_appsignal?(options)
          puts "\nDiagnostics report"
          puts "  Do you want to send this diagnostics report to AppSignal?"
          puts "  If you share this report you will be given a link to \n" \
            "  AppSignal.com to validate the report.\n" \
            "  You can also contact us at support@appsignal.com\n" \
            "  with your support token.\n\n"
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
          puts "  Transmitting diagnostics report"
          transmitter = Transmitter.new(
            ENV.fetch("APPSIGNAL_DIAGNOSE_ENDPOINT", DIAGNOSE_ENDPOINT),
            Appsignal.config
          )
          response = transmitter.transmit(:diagnose => data)

          unless response.code == "200"
            puts "  Error: Something went wrong while submitting the report " \
              "to AppSignal."
            puts "  Response code: #{response.code}"
            puts "  Response body:\n#{response.body}"
            return
          end

          begin
            response_data = JSON.parse(response.body)
            puts "\n  Your support token: #{response_data["token"]}"
            puts "  View this report:   https://appsignal.com/diagnose/#{response_data["token"]}"
          rescue JSON::ParserError
            puts "  Error: Couldn't decode server response."
            puts "  #{response.body}"
          end
        end

        def puts_and_save(key, label, value)
          save key, value
          puts_value label, value
        end

        # Prints values as given. Does no formatting on the value
        def puts_value(label, value, options = {})
          options[:level] ||= 1
          puts "#{"  " * options[:level]}#{label}: #{value}"
        end

        # Print values as inspected.
        # Surrounds Strings in quotes.
        def puts_format(label, value, options = {})
          puts_value label, value.inspect, options
        end

        def configure_appsignal(options)
          current_path = Dir.pwd
          initial_config = {}
          if rails_app?
            data[:app][:rails] = true
            current_path = Rails.root
            initial_config[:name] =
              Appsignal::Utils::RailsHelper.detected_rails_app_name
            initial_config[:log_path] = current_path.join("log")
          end

          Appsignal.config = Appsignal::Config.new(
            current_path,
            options.fetch(:environment, ENV.fetch("RACK_ENV", ENV.fetch("RAILS_ENV", nil))),
            initial_config
          )
          Appsignal.config.write_to_environment
          Appsignal.start_logger
          Appsignal.internal_logger.info("Starting AppSignal diagnose")
        end

        def run_agent_diagnose_mode
          puts "Agent diagnostics"
          unless Appsignal.extension_loaded?
            puts colorize("  Extension is not loaded. No agent report created.", :red)
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
          puts "https://docs.appsignal.com/"
          puts "Send this output to support@appsignal.com if you need help."
          puts "=" * 80
        end

        def library_information
          puts "AppSignal library"
          data_section :library do
            save :language, "ruby"
            puts_value "Language", "Ruby"

            package_version = Appsignal::VERSION
            save :package_version, package_version
            puts_format "Gem version", package_version

            agent_version = Appsignal::Extension.agent_version
            save :agent_version, agent_version
            puts_format "Agent version", agent_version

            extension_loaded = Appsignal.extension_loaded
            save :extension_loaded, extension_loaded
            puts_format "Extension loaded", extension_loaded
          end
        end

        def fetch_installation_report
          path = File.expand_path("../../../ext/install.report", __dir__)
          raw_report = File.read(path)
          JSON.parse(raw_report)
        rescue StandardError, JSON::ParserError => e # rubocop:disable Lint/ShadowedException
          {
            "parsing_error" => {
              "error" => "#{e.class}: #{e}",
              "backtrace" => e.backtrace
            }.tap do |r|
              r["raw"] = raw_report if raw_report
            end
          }
        end

        def print_installation_report
          puts "\nExtension installation report"
          install_report = data[:installation]
          if install_report.key? "parsing_error"
            print_installation_report_parsing_error(install_report)
            return
          end

          print_installation_result_report(install_report)
          print_installation_language_report(install_report)
          print_installation_download_report(install_report)
          print_installation_build_report(install_report)
          print_installation_host_report(install_report)
        end

        def print_installation_report_parsing_error(report)
          report = report["parsing_error"]
          puts "  Error found while parsing the report."
          puts "  Error: #{report["error"]}"
          puts "  Raw report:\n#{report["raw"]}" if report["raw"]
        end

        def print_installation_result_report(report)
          report = report.fetch("result", {})
          puts "  Installation result"
          puts "    Status: #{report["status"]}"
          puts "    Message: #{report["message"]}" if report["message"]
          puts "    Error: #{report["error"]}" if report["error"]
        end

        def print_installation_language_report(report)
          report = report.fetch("language", {})
          puts "  Language details"
          puts_format "Implementation", report["implementation"], :level => 2
          puts_format "Ruby version", report["version"], :level => 2
        end

        def print_installation_download_report(report)
          report = report.fetch("download", {})
          puts "  Download details"
          puts_format "Download URL", report["download_url"], :level => 2
          puts_format "Checksum", report["checksum"], :level => 2
        end

        def print_installation_build_report(report)
          report = report.fetch("build", {})
          puts "  Build details"
          puts_format "Install time", report["time"], :level => 2
          puts_format "Architecture", report["architecture"], :level => 2
          puts_format "Target", report["target"], :level => 2
          puts_format "Musl override", report["musl_override"], :level => 2
          puts_format "Linux ARM override", report["linux_arm_override"], :level => 2
          puts_format "Library type", report["library_type"], :level => 2
          puts_format "Source", report["source"], :level => 2 if report["source"] != "remote"
          puts_format "Dependencies", report["dependencies"], :level => 2
          puts_format "Flags", report["flags"], :level => 2
        end

        def print_installation_host_report(report)
          report = report.fetch("host", {})
          puts "  Host details"
          puts "    Root user: #{report["root_user"]}"
          puts "    Dependencies: #{report["dependencies"]}"
        end

        def host_information
          rbconfig = RbConfig::CONFIG
          puts "Host information"
          data_section :host do
            agent_architecture = Appsignal::System.agent_architecture
            save :architecture, agent_architecture
            puts_format "Architecture", agent_architecture

            os = rbconfig["host_os"]
            os_label = os.inspect
            os_label = "#{os_label} (Microsoft Windows is not supported.)" if Gem.win_platform?
            save :os, os
            puts_value "Operating System", os_label

            distribution_file = "/etc/os-release"
            save :os_distribution,
              File.exist?(distribution_file) ? File.read(distribution_file) : ""

            language_version = "#{rbconfig["RUBY_PROGRAM_VERSION"]}-p#{rbconfig["PATCHLEVEL"]}"
            save :language_version, language_version
            puts_format "Ruby version", language_version

            heroku = Appsignal::System.heroku?
            save :heroku, heroku
            puts_format "Heroku", true if Appsignal::System.heroku?

            root = Process.uid.zero?
            save :root, root
            puts_value "Root user", root ? "true (not recommended)" : "false"

            running_in_container = Appsignal::Extension.running_in_container?
            save :running_in_container, running_in_container
            puts_format "Running in container", running_in_container
          end
        end

        def print_config_section
          puts "Configuration"
          config = Appsignal.config
          data[:config] = {
            :options => config.config_hash.merge(:env => config.env),
            :sources => {
              :default => Appsignal::Config::DEFAULT_CONFIG,
              :system => config.system_config,
              :initial => config.initial_config,
              :file => config.file_config,
              :env => config.env_config,
              :override => config.override_config
            },
            :modifiers => {
              "APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR" =>
                ENV.fetch("APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR", "")
            }
          }
          print_config_options(config)
        end

        def print_environment(config)
          env = config.env
          option = :env
          option_sources = sources_for_option(option)
          sources_label = config_sources_label(option, option_sources)
          print "  environment: #{format_config_option(env)}"

          if env == ""
            message = "    Warning: No environment set, no config loaded!\n" \
              "    Please make sure appsignal diagnose is run within your\n" \
              "    project directory with an environment.\n" \
              "      appsignal diagnose --environment=production"
            puts "\n#{colorize(message, :red)}"
          else
            puts sources_label
          end
        end

        def print_config_options(config)
          # We add the nullified "environment" key to print it ordered
          # instead of adding it at the top of the list.
          ordered_config_options = config
            .config_hash
            .merge(:environment => nil)
            .sort

          ordered_config_options.each do |key, value|
            option_sources = sources_for_option(key)
            sources_label = config_sources_label(key, option_sources)

            if key == :environment
              print_environment(config)
            else
              puts "  #{key}: #{format_config_option(value)}#{sources_label}"
            end
          end

          puts
          puts "Configuration modifiers"
          puts "  APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR: " \
            "#{data[:config][:modifiers]["APPSIGNAL_INACTIVE_ON_CONFIG_FILE_ERROR"].inspect}"

          puts "\nRead more about how the diagnose config output is rendered\n" \
            "https://docs.appsignal.com/ruby/command-line/diagnose.html"
        end

        def sources_for_option(option)
          config_sources = data[:config][:sources]
          [].tap do |option_sources|
            config_sources.each do |source, c|
              option_sources << source if c.key?(option)
            end
          end
        end

        def config_sources_label(option, sources)
          return if sources == [:default]

          if sources.length == 1
            " (Loaded from: #{sources.join(", ")})"
          elsif sources.any?
            ["\n    Sources:"].tap do |a|
              max_source_length = sources.map(&:length).max + 1 # 1 is for ":"
              sources.each do |source|
                source_label = "#{source}:".ljust(max_source_length)
                value = data[:config][:sources][source][option]
                a << "      #{source_label} #{format_config_option(value)}"
              end
            end.join("\n")
          else
            " (Not configured)"
          end
        end

        def format_config_option(value)
          case value
          when NilClass
            "nil"
          when String
            value.inspect
          else
            value
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
          auth_check = ::Appsignal::AuthCheck.new(Appsignal.config)
          status, error = auth_check.perform_with_result
          result, color =
            case status
            when "200"
              ["valid", :green]
            when "401"
              ["invalid", :red]
            else
              ["Failed to validate: status #{status}\n#{error.inspect}", :red]
            end
          data[:validation][:push_api_key] = result
          puts_value "Validating Push API key", colorize(result, color)
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
            print_empty_line
            return
          end

          puts_value "Writable?", path[:writable], :level => 2

          ownership = path[:ownership]
          owned = process_user[:uid] == ownership[:uid]
          owner = "#{owned} " \
            "(file: #{ownership[:user]}:#{ownership[:uid]}, " \
            "process: #{process_user[:user]}:#{process_user[:uid]})"
          puts_value "Ownership?", owner, :level => 2

          if path.key?(:content)
            puts "    Contents (last 10 lines):"
            puts path[:content].last(10)
          else
            print_empty_line
          end

          return unless path.key?(:read_error)

          puts "    Read error: #{path[:read_error]}"
          print_empty_line
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
