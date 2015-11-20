module Appsignal
  class Hooks
    class << self
      def register(name, hook)
        hooks[name] = hook
      end

      def load_hooks
        hooks.each do |name, hook|
          hook.try_to_install(name)
        end
      end

      def hooks
        @hooks ||= {}
      end
    end

    class Hook
      def self.register(name, hook=self)
        Appsignal::Hooks.register(name, hook.new)
      end

      def try_to_install(name)
        if dependencies_present? && !installed?
          Appsignal.logger.info("Installing #{name} hook")
          begin
            install
            @installed = true
          rescue => ex
            Appsignal.logger.error("Error while installing #{name} hook: #{ex}")
          end
        end
      end

      def installed?
        !! @installed
      end

      def dependencies_present?
        raise NotImplementedError
      end

      def install
        raise NotImplementedError
      end
    end
  end
end

require 'appsignal/hooks/celluloid'
require 'appsignal/hooks/delayed_job'
require 'appsignal/hooks/passenger'
require 'appsignal/hooks/puma'
require 'appsignal/hooks/rake'
require 'appsignal/hooks/resque'
require 'appsignal/hooks/sidekiq'
require 'appsignal/hooks/unicorn'
