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

    module Helpers

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def truncate(text)
          Appsignal::Hooks::Helpers.truncate(text)
        end

        def string_or_inspect(string_or_other)
          Appsignal::Hooks::Helpers.string_or_inspect(string_or_other)
        end
      end

      def string_or_inspect(string_or_other)
        Appsignal::Hooks::Helpers.string_or_inspect(string_or_other)
      end

      def truncate(text)
        Appsignal::Hooks::Helpers.truncate(text)
      end

      def self.string_or_inspect(string_or_other)
        if string_or_other.is_a?(String)
          string_or_other
        else
          string_or_other.inspect
        end
      end

      def self.truncate(text)
        text.size > 200 ? "#{text[0...197]}..." : text
      end
    end

  end
end

require 'appsignal/hooks/celluloid'
require 'appsignal/hooks/delayed_job'
require 'appsignal/hooks/net_http'
require 'appsignal/hooks/passenger'
require 'appsignal/hooks/puma'
require 'appsignal/hooks/rake'
require 'appsignal/hooks/redis'
require 'appsignal/hooks/resque'
require 'appsignal/hooks/sequel'
require 'appsignal/hooks/sidekiq'
require 'appsignal/hooks/unicorn'
require 'appsignal/hooks/mongo_ruby_driver'
