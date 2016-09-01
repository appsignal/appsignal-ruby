require 'optparse'
require 'logger'
require 'yaml'
require 'appsignal'
require 'appsignal/cli/diagnose'
require 'appsignal/cli/install'
require 'appsignal/cli/notify_of_deploy'

module Appsignal
  class CLI
    AVAILABLE_COMMANDS = %w(diagnose install notify_of_deploy).freeze

    class << self
      attr_accessor :options, :initial_config
      attr_writer :config

      def run(argv=ARGV)
        @options = {}
        @initial_config = {}
        global = global_option_parser
        commands = command_option_parser
        global.order!(argv)
        command = argv.shift
        if command
          if AVAILABLE_COMMANDS.include?(command)
            commands[command].parse!(argv)
            case command.to_sym
            when :diagnose
              Appsignal::CLI::Diagnose.run
            when :install
              Appsignal::CLI::Install.run(argv.shift, config)
            when :notify_of_deploy
              Appsignal::CLI::NotifyOfDeploy.run(options, config)
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

      def config
        Appsignal::Config.new(
          Dir.pwd,
          options[:environment],
          initial_config,
          Logger.new(StringIO.new)
        )
      end

      def global_option_parser
        OptionParser.new do |o|
          o.banner = 'Usage: appsignal <command> [options]'

          o.on '-v', '--version', "Print version and exit" do |arg|
            puts "Appsignal #{Appsignal::VERSION}"
            exit(0)
          end

          o.on '-h', '--help', "Show help and exit" do
            puts o
            exit(0)
          end

          o.separator ''
          o.separator "Available commands: #{AVAILABLE_COMMANDS.join(', ')}"
        end
      end

      def command_option_parser
        {
          'diagnose' => OptionParser.new,
          'install' => OptionParser.new,
          'notify_of_deploy' => OptionParser.new do |o|
            o.banner = 'Usage: appsignal notify_of_deploy [options]'

            o.on '--revision=<revision>', "The revision you're deploying" do |arg|
              options[:revision] = arg
            end

            o.on '--user=<user>', "The name of the user that's deploying" do |arg|
              options[:user] = arg
            end

            o.on '--environment=<rails_env>', "The environment you're deploying to" do |arg|
              options[:environment] = arg
            end

            o.on '--name=<name>', "The name of the app (optional)" do |arg|
              initial_config[:name] = arg
            end
          end
        }
      end
    end
  end
end
