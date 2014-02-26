require 'capistrano'

module Appsignal
  module Integrations
    class Capistrano
      class Notifier
        attr_reader :config, :env, :revision, :repo_url, :logger

        def initialize(options)
          @config = options.delete(:config)
          @env = options.delete(:env)
          @revision = options.delete(:revision)
          @repo_url = options.delete(:repo_url)
          @logger = options.delete(:logger)
        end

        def notify
          appsignal_config = Appsignal::Config.new(
            ENV['PWD'],
            env,
            config,
            logger
          )

          if appsignal_config && appsignal_config.active?
            marker_data = {
              revision: revision,
              repository: repo_url,
              user: ENV['USER'] || ENV['USERNAME']
            }

            marker = Appsignal::Marker.new(
              marker_data,
              appsignal_config,
              logger
            )
            marker.transmit
          end
        end
      end
    end
  end
end
