# frozen_string_literal: true

module Appsignal
  # @api private
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

      def extract_value(object_or_hash, field, default_value = nil, convert_to_s = false)
        value = nil

        # Attempt to read value from hash
        if object_or_hash.respond_to?(:[])
          value = begin
            object_or_hash[field]
          rescue NameError
            nil
          end
        end

        # Attempt to read value from object
        if !value && object_or_hash.respond_to?(field)
          value = object_or_hash.send(field)
        end

        # Set default value if nothing was found
        value ||= default_value

        if convert_to_s
          value.to_s
        else
          value
        end
      end
    end
  end
end

require "appsignal/hooks/action_cable"
require "appsignal/hooks/active_support_notifications"
require "appsignal/hooks/celluloid"
require "appsignal/hooks/delayed_job"
require "appsignal/hooks/net_http"
require "appsignal/hooks/passenger"
require "appsignal/hooks/puma"
require "appsignal/hooks/rake"
require "appsignal/hooks/redis"
require "appsignal/hooks/sequel"
require "appsignal/hooks/shoryuken"
require "appsignal/hooks/sidekiq"
require "appsignal/hooks/unicorn"
require "appsignal/hooks/mongo_ruby_driver"
require "appsignal/hooks/webmachine"
require "appsignal/hooks/data_mapper"
require "appsignal/hooks/que"
