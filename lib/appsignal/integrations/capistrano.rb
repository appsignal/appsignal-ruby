require 'capistrano'
begin
  require 'capistrano/all'
rescue
end

require 'appsignal/integrations/capistrano/notifier'

module Appsignal
  module Integrations
    class Capistrano
      def self.capistrano3?
        ! ::Capistrano::Configuration.respond_to?(:instance)
      end

      def self.capistrano2?
        ::Capistrano::Configuration.respond_to?(:instance) &&
        ::Capistrano::Configuration.instance
      end

      def self.tasks(config)
        config.load do
          after 'deploy', 'appsignal:deploy'
          after 'deploy:migrations', 'appsignal:deploy'

          namespace :appsignal do
            desc 'Notify AppSignal of this deploy'
            task :deploy do
              notifier = Appsignal::Integrations::Capistrano::Notifier.new({
                config: fetch(:appsignal_config, {}),
                env: fetch(:rails_env, fetch(:rack_env, 'production')),
                revision: current_revision,
                repo_url: repository,
                logger: logger
              })
              if config.dry_run
                logger.info('Dry run: Deploy marker not actually sent.')
              else
                notifier.notify
              end
            end
          end
        end
      end
    end
  end
end

if Appsignal::Integrations::Capistrano.capistrano3?
  load File.expand_path('../capistrano/deploy.rake', __FILE__)
elsif Appsignal::Integrations::Capistrano.capistrano2?
  Appsignal::Integrations::Capistrano.tasks(
    ::Capistrano::Configuration.instance
  )
end
