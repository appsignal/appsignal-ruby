require 'optparse'
require 'logger'
require 'yaml'
require 'rails'
require 'appsignal/version'
require 'appsignal/config'
require 'appsignal/marker'
require 'appsignal/transmitter'

module Appsignal
  class CLI
    AVAILABLE_COMMANDS = %w(notify_of_deploy)

    class << self
      def run(argv=ARGV)
        unless File.exists?(File.join(ENV['PWD'], 'config/appsignal.yml'))
          puts 'No config file present at config/appsignal.yml'
          puts 'Log in to https://appsignal.com to get instructions on how to generate the config file.'
          exit(1)
        end
        options = {}
        global = global_option_parser(options)
        commands = command_option_parser(options)

        global.order!(argv)
        command = argv.shift
        if command then
          if AVAILABLE_COMMANDS.include?(command)
            commands[command].parse!(argv)
            case options[:command]
            when :notify_of_deploy
              notify_of_deploy(options)
            end
          else
            puts "Command '#{command}' does not exist, run appsignal -h to see the help"
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

      def global_option_parser(options)
        OptionParser.new do |o|
          o.banner = %Q{Usage: appsignal <command> [options]}

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

      def command_option_parser(options)
        {
          'notify_of_deploy' => OptionParser.new do |o|
            o.banner = %Q{Usage: appsignal notify_of_deploy [options] }
            options[:command] = :notify_of_deploy

            o.on '--revision=<revision>', "The revision you're deploying" do |arg|
              options[:revision] = arg
            end

            o.on '--repository=<repository>', "The location of the main code repository" do |arg|
              options[:repository] = arg
            end

            o.on '--user=<user>', "The name of the user that's deploying" do |arg|
              options[:user] = arg
            end

            o.on '--environment=<rails_env>', "The environment you're deploying to" do |arg|
              options[:environment] = arg
            end
          end
        }
      end

      def notify_of_deploy(options)
        validate_required_options([:revision, :repository, :user, :environment], options)
        Appsignal::Marker.new(
          {
            :revision => options[:revision],
            :repository => options[:repository],
            :user => options[:user]
          },
          ENV['PWD'],
          options[:environment],
          logger
        ).transmit
      end

      def validate_required_options(required_options, options)
        missing = required_options.select do |required_option|
          options[required_option].blank?
        end
        if missing.any?
          puts "Missing options: #{missing.join(', ')}"
          exit(1)
        end
      end
    end
  end
end
