require 'capistrano'
require 'rails'
require 'appsignal/version'
require 'appsignal/config'
require 'appsignal/transmitter'
require 'appsignal/marker'

module Appsignal
  class Capistrano
    def self.tasks(config)
      config.load do
        after "deploy", "appsignal:deploy"
        after "deploy:migrations", "appsignal:deploy"

        namespace :appsignal do
          task :deploy do
            rails_env = fetch(:rails_env, 'production')
            user = ENV['USER'] || ENV['USERNAME']

            marker_data = {
              :revision => current_revision,
              :repository => repository,
              :user => user
            }

            marker = Marker.new(marker_data, ENV['PWD'], rails_env, logger)
            if config.dry_run
              logger.info("Dry run: Deploy marker not actually sent.")
            else
              marker.transmit
            end
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Appsignal::Capistrano.tasks(Capistrano::Configuration.instance)
end
