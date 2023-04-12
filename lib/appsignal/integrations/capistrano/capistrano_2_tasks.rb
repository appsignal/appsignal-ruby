# frozen_string_literal: true

module Appsignal
  # @todo Move to sub-namespace
  # @api private
  class Capistrano
    def self.tasks(config)
      config.load do # rubocop:disable Metrics/BlockLength
        after "deploy", "appsignal:deploy"
        after "deploy:migrations", "appsignal:deploy"

        namespace :appsignal do
          task :deploy do
            env = fetch(:appsignal_env,
              fetch(:stage, fetch(:rails_env, fetch(:rack_env, "production"))))
            user = fetch(:appsignal_user, ENV["USER"] || ENV.fetch("USERNAME", nil))
            revision = fetch(:appsignal_revision, fetch(:current_revision))

            appsignal_config = Appsignal::Config.new(
              ENV.fetch("PWD", nil),
              env,
              {},
              Appsignal::Utils::IntegrationLogger.new(StringIO.new)
            ).tap do |c|
              fetch(:appsignal_config, {}).each do |key, value|
                c[key] = value
              end
              c.validate
            end

            if appsignal_config&.active?
              marker_data = {
                :revision => revision,
                :user => user
              }

              marker = Marker.new(marker_data, appsignal_config)
              if config.dry_run
                puts "Dry run: AppSignal deploy marker not actually sent."
              else
                marker.transmit
              end
            else
              puts "Not notifying of deploy, config is not active for environment: #{env}"
            end
          end
        end
      end
    end
  end
end

if ::Capistrano::Configuration.instance
  Appsignal::Capistrano.tasks(::Capistrano::Configuration.instance)
end
