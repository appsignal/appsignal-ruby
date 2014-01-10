require 'capistrano'

module Appsignal
  module Integrations
    class Capistrano
      def self.tasks(config)
        config.load do
          after 'deploy', 'appsignal:deploy'
          after 'deploy:migrations', 'appsignal:deploy'

          namespace :appsignal do
            task :deploy do
              env = fetch(:rails_env, fetch(:rack_env, 'production'))
              user = ENV['USER'] || ENV['USERNAME']

              appsignal_config = Appsignal::Config.new(
                ENV['PWD'],
                env,
                {},
                logger
              )

              if appsignal_config && appsignal_config.active?
                marker_data = {
                  :revision => current_revision,
                  :repository => repository,
                  :user => user
                }

                marker = Marker.new(marker_data, appsignal_config, logger)
                if config.dry_run
                  logger.info('Dry run: Deploy marker not actually sent.')
                else
                  marker.transmit
                end
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
