module Appsignal
  class CLI
    # Command line tool to send a "Deploy Marker" for an application to
    # AppSignal.
    #
    # Deploy markers are used on AppSignal.com to indicate changes in an
    # application, "Deploy markers" indicate a deploy of an application.
    #
    # Incidents for exceptions and performance issues will be closed and
    # reopened if they occur again in the new deploy.
    #
    # @note The same logic is used in the Capistrano integration. A deploy
    #   marker is created on each deploy.
    #
    # ## Options
    #
    # - `--environment` required. The environment of the application being
    #   deployed.
    # - `--user` required. User that triggered the deploy.
    # - `--revision` required. Git commit SHA or other identifiable revision id.
    # - `--name` If no "name" config can be found in a `config/appsignal.yml`
    #   file or based on the `APPSIGNAL_APP_NAME` environment variable, this
    #   option is required.
    #
    # ## Exit codes
    #
    # - Exits with status code `0` if the deploy marker is sent.
    # - Exits with status code `1` if the configuration is not valid and active.
    # - Exits with status code `1` if the required options aren't present.
    #
    # @example basic example
    #   appsignal notify_of_deploy \
    #     --user=tom \
    #     --environment=production \
    #     --revision=abc1234
    #
    # @example using a custom app name
    #   appsignal notify_of_deploy \
    #     --user=tom \
    #     --environment=production \
    #     --revision=abc1234 \
    #     --name="My app"
    #
    # @example help command
    #   appsignal notify_of_deploy --help
    #
    # @since 0.2.5
    # @see Appsignal::Marker Appsignal::Marker
    # @see http://docs.appsignal.com/ruby/command-line/notify_of_deploy.html
    #   AppSignal notify_of_deploy documentation
    # @see http://docs.appsignal.com/appsignal/terminology.html#markers
    #   Terminology: Deploy marker
    class NotifyOfDeploy
      class << self
        # @param options [Hash]
        # @option options :environment [String] environment to load
        #   configuration for.
        # @option options :name [String] custom name of the application.
        # @option options :user [String] user who triggered the deploy.
        # @option options :revision [String] the revision that has been
        #   deployed. E.g. a git commit SHA.
        # @return [void]
        def run(options)
          config = config_for(options[:environment])
          config[:name] = options[:name] if options[:name]

          validate_active_config(config)
          required_config = [:revision, :user]
          required_config << :environment if config.env.empty?
          required_config << :name if !config[:name] || config[:name].empty?
          validate_required_options(options, required_config)

          Appsignal::Marker.new(
            {
              :revision => options[:revision],
              :user => options[:user]
            },
            config
          ).transmit
        end

        private

        def validate_required_options(options, required_options)
          missing = required_options.select do |required_option|
            val = options[required_option]
            val.nil? || (val.respond_to?(:empty?) && val.empty?)
          end
          return unless missing.any?

          puts "Error: Missing options: #{missing.join(", ")}"
          exit 1
        end

        def validate_active_config(config)
          return if config.active?

          puts "Error: No valid config found."
          exit 1
        end

        def config_for(environment)
          Appsignal::Config.new(
            Dir.pwd,
            environment,
            {},
            Logger.new(StringIO.new)
          )
        end
      end
    end
  end
end
