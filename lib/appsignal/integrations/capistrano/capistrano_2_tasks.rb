# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    class Capistrano
      def self.tasks(config)
        config.load do
          after "deploy", "appsignal:deploy"
          after "deploy:migrations", "appsignal:deploy"

          namespace :appsignal do
            task :deploy do
              appsignal_env = fetch(:appsignal_env,
                fetch(:stage, fetch(:rails_env, fetch(:rack_env, "production"))))
              user = fetch(:appsignal_user, ENV["USER"] || ENV.fetch("USERNAME", nil))
              revision = fetch(:appsignal_revision, fetch(:current_revision))

              Appsignal._load_config!(appsignal_env) do |conf|
                conf&.merge_dsl_options(fetch(:appsignal_config, {}))
              end
              Appsignal._start_logger

              if Appsignal.config&.active?
                marker_data = {
                  :revision => revision,
                  :user => user
                }

                marker = Marker.new(marker_data, Appsignal.config)
                if config.dry_run
                  puts "Dry run: AppSignal deploy marker not actually sent."
                else
                  marker.transmit
                end
              else
                puts "Not notifying of deploy, config is not active for " \
                  "environment: #{appsignal_env}"
              end
            end
          end
        end
      end
    end
  end
end

if ::Capistrano::Configuration.instance
  Appsignal::Integrations::Capistrano.tasks(::Capistrano::Configuration.instance)
end
