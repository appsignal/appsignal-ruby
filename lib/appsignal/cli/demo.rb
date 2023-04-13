# frozen_string_literal: true

require "appsignal/demo"

module Appsignal
  class CLI
    # Command line tool for sending demonstration samples to AppSignal.com
    #
    # This command line tool is useful when testing AppSignal on a system and
    # validating the local configuration. It tests if the installation of
    # AppSignal has succeeded and if the AppSignal agent is able to run on the
    # machine's architecture and communicate with the AppSignal servers.
    #
    # The same test is also run during installation with
    # {Appsignal::CLI::Install}.
    #
    # ## Exit codes
    #
    # - Exits with status code `0` if the demo command has finished.
    # - Exits with status code `1` if the demo command failed to finished.
    #
    # @example On the command line in your project
    #   appsignal demo
    #
    # @example With a specific environment
    #   appsignal demo --environment=production
    #
    # @example Standalone run
    #   gem install appsignal
    #   export APPSIGNAL_APP_NAME="My test app"
    #   export APPSIGNAL_APP_ENV="test"
    #   export APPSIGNAL_PUSH_API_KEY="xxxx-xxxx-xxxx-xxxx"
    #   appsignal demo
    #
    # @since 2.0.0
    # @see Appsignal::Demo
    # @see Appsignal::CLI::Install
    # @see https://docs.appsignal.com/ruby/command-line/demo.html
    #   AppSignal demo documentation
    # @see https://docs.appsignal.com/support/debugging.html
    #   Debugging AppSignal guide
    # @api private
    class Demo
      class << self
        # @param options [Hash]
        # @option options :environment [String] environment to load
        #   configuration for.
        # @return [void]
        def run(options = {})
          ENV["APPSIGNAL_APP_ENV"] = options[:environment] if options[:environment]

          puts "Sending demonstration sample data..."
          if Appsignal::Demo.transmit
            puts "Demonstration sample data sent!"
            puts "It may take about a minute for the data to appear on " \
              "https://appsignal.com/accounts"
          else
            puts "\nError: Unable to start the AppSignal agent and send data to AppSignal.com."
            puts "Please use the diagnose command " \
              "(https://docs.appsignal.com/ruby/command-line/diagnose.html) " \
              "to debug your configuration:"
            puts
            puts "    bundle exec appsignal diagnose --environment=production"
            puts
            exit 1
          end
        end
      end
    end
  end
end
