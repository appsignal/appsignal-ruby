# frozen_string_literal: true

require "optparse"
require "logger"
require "appsignal"
require "appsignal/cli/helpers"
require "appsignal/cli/demo"
require "appsignal/cli/diagnose"
require "appsignal/cli/install"
require "appsignal/cli/notify_of_deploy"

module Appsignal
  # @api private
  class CLI
    AVAILABLE_COMMANDS = %w[demo diagnose install notify_of_deploy].freeze

    class << self
      attr_accessor :options

      def run(argv = ARGV)
        @options = {}
        global = global_option_parser
        commands = command_option_parser
        global.order!(argv)
        command = argv.shift
        if command
          if AVAILABLE_COMMANDS.include?(command)
            commands[command].parse!(argv)
            case command.to_sym
            when :demo
              Appsignal::CLI::Demo.run(options)
            when :diagnose
              Appsignal::CLI::Diagnose.run(options)
            when :install
              Appsignal::CLI::Install.run(argv.shift, options)
            when :notify_of_deploy
              Appsignal::CLI::NotifyOfDeploy.run(options)
            end
          else
            puts "Command '#{command}' does not exist, run appsignal -h to "\
              "see the help"
            exit(1)
          end
        else
          # Print help
          puts global
          exit(0)
        end
      end

      def global_option_parser
        OptionParser.new do |o|
          o.banner = "Usage: appsignal <command> [options]"

          o.on "-v", "--version", "Print version and exit" do |_arg|
            puts "AppSignal #{Appsignal::VERSION}"
            exit(0)
          end

          o.on "-h", "--help", "Show help and exit" do
            puts o
            exit(0)
          end

          o.separator ""
          o.separator "Available commands: #{AVAILABLE_COMMANDS.join(", ")}"
        end
      end

      def command_option_parser
        {
          "demo" => OptionParser.new do |o|
            o.banner = "Usage: appsignal demo [options]"

            o.on "--environment=<app_env>", "The environment to demo" do |arg|
              options[:environment] = arg
            end
          end,
          "diagnose" => OptionParser.new do |o|
            o.banner = "Usage: appsignal diagnose [options]"

            o.on "--environment=<app_env>", "The environment to diagnose" do |arg|
              options[:environment] = arg
            end
            o.on "--[no-]send-report", "Confirm sending the report to AppSignal automatically" do |arg|
              options[:send_report] = arg
            end
          end,
          "install" => OptionParser.new do |o|
            o.on "--[no-]color", "Colorize the output of the diagnose command" do |arg|
              options[:color] = arg
            end
          end,
          "notify_of_deploy" => OptionParser.new do |o|
            o.banner = "Usage: appsignal notify_of_deploy [options]"

            o.on "--revision=<revision>", "The revision you're deploying" do |arg|
              options[:revision] = arg
            end

            o.on "--user=<user>", "The name of the user that's deploying" do |arg|
              options[:user] = arg
            end

            o.on "--environment=<app_env>", "The environment you're deploying to" do |arg|
              options[:environment] = arg
            end

            o.on "--name=<name>", "The name of the app (optional)" do |arg|
              options[:name] = arg
            end
          end
        }
      end
    end
  end
end
