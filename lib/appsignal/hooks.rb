# frozen_string_literal: true

module Appsignal
  # @!visibility private
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
      def self.register(name, hook = self)
        Appsignal::Hooks.register(name, hook.new)
      end

      def initialize
        @installed = false
      end

      def try_to_install(name)
        return unless dependencies_present?
        return if installed?

        Appsignal.internal_logger.debug("Installing #{name} hook")
        begin
          install
          @installed = true
        rescue => ex
          logger = Appsignal.internal_logger
          logger.error(
            "Error while installing #{name} hook: #{ex.class}: #{ex.message}\n" \
              "#{ex.backtrace.join("\n")}"
          )
        end
      end

      def installed?
        @installed
      end

      def dependencies_present?
        raise NotImplementedError
      end

      def install
        raise NotImplementedError
      end
    end

    module Helpers
      def string_or_inspect(string_or_other)
        if string_or_other.is_a?(String)
          string_or_other
        else
          string_or_other.inspect
        end
      end

      def truncate(text)
        text.size > 200 ? "#{text[0...197]}..." : text
      end
    end
  end
end

require "appsignal/hooks/at_exit"
require "appsignal/hooks/action_cable"
require "appsignal/hooks/action_mailer"
require "appsignal/hooks/active_job"
require "appsignal/hooks/active_support_notifications"
require "appsignal/hooks/celluloid"
require "appsignal/hooks/delayed_job"
require "appsignal/hooks/gvl"
require "appsignal/hooks/dry_monitor"
require "appsignal/hooks/http"
require "appsignal/hooks/mri"
require "appsignal/hooks/net_http"
require "appsignal/hooks/ownership"
require "appsignal/hooks/passenger"
require "appsignal/hooks/puma"
require "appsignal/hooks/rake"
require "appsignal/hooks/redis"
require "appsignal/hooks/redis_client"
require "appsignal/hooks/resque"
require "appsignal/hooks/sequel"
require "appsignal/hooks/shoryuken"
require "appsignal/hooks/sidekiq"
require "appsignal/hooks/unicorn"
require "appsignal/hooks/mongo_ruby_driver"
require "appsignal/hooks/webmachine"
require "appsignal/hooks/data_mapper"
require "appsignal/hooks/que"
require "appsignal/hooks/excon"
