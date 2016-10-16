module Appsignal
  class CLI
    class NotifyOfDeploy
      class << self
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

          puts "Error: Missing options: #{missing.join(', ')}"
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
