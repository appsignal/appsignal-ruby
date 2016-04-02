module Appsignal
  class Capistrano
    def self.tasks(config)
      config.load do
        after 'deploy', 'appsignal:deploy'
        after 'deploy:migrations', 'appsignal:deploy'

        namespace :appsignal do
          task :deploy do
            env = fetch(:rails_env, fetch(:rack_env, 'production'))
            user = ENV['USER'] || ENV['USERNAME']
            revision = fetch(:appsignal_revision, fetch(:current_revision))

            appsignal_config = Appsignal::Config.new(
              ENV['PWD'],
              env,
              fetch(:appsignal_config, {}),
              Logger.new(StringIO.new)
            )

            if appsignal_config && appsignal_config.active?
              marker_data = {
                :revision => revision,
                :user => user
              }

              marker = Marker.new(marker_data, appsignal_config)
              if config.dry_run
                puts 'Dry run: AppSignal deploy marker not actually sent.'
              else
                marker.transmit
              end
            else
              puts 'Not notifying of deploy, config is not active'
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
