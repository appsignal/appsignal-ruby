require 'capistrano'
require 'appsignal/transmitter'
require 'appsignal/marker'

module Appsignal
  class Capistrano
    def self.tasks(config)
      config.load do
        after "deploy","appsignal:deploy"
        after "deploy:migrations", "appsignal:deploy"

        namespace :appsignal do
          task :deploy do
            rails_env = fetch(:rails_env, "production")
            user = ENV['USER'] || ENV['USERNAME']

            marker_data = {
              :revision => current_revision,
              :repository => repository,
              :user => user,
              :rails_env => rails_env
            }

            marker = Marker.new(marker_data, rails_env, logger)
            marker.transmit
          end
        end
      end
    end
  end
end

if Capistrano::Configuration.instance
  Appsignal::Capistrano.tasks(Capistrano::Configuration.instance)
end
