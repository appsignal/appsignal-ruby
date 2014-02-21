require 'optparse'
require 'logger'
require 'yaml'
require 'appsignal'

module Appsignal
  class CLI
    AVAILABLE_COMMANDS = %w(notify_of_deploy).freeze

    class << self
      attr_accessor :options, :config, :initial_config

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
            when :notify_of_deploy
              notify_of_deploy
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

      def logger
        Logger.new($stdout)
      end

      def config
        @config ||= Appsignal::Config.new(
          ENV['PWD'],
          options[:environment],
          @initial_config,
          logger
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

      def notify_of_deploy
        validate_active_config
        validate_required_options([:revision, :user, :environment])

        Appsignal::Marker.new(
          {
            :revision => options[:revision],
            :user => options[:user]
          },
          config,
          logger
        ).transmit
      end

      protected

      def validate_required_options(required_options)
        missing = required_options.select do |required_option|
          options[required_option].blank?
        end
        if missing.any?
          puts "Missing options: #{missing.join(', ')}"
          exit(1)
        end
      end

      def validate_active_config
        unless config.active?
          puts 'Exiting: No config file or push api key env var found'
          exit(1)
        end
      end
    end
  end
end
