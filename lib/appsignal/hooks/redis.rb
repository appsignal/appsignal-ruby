# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class RedisHook < Appsignal::Hooks::Hook
      register :redis

      def dependencies_present?
        defined?(::Redis) &&
          Appsignal.config &&
          Appsignal.config[:instrument_redis]
      end

      def install
        require "appsignal/integrations/redis"
        ::Redis::Client.prepend Appsignal::Integrations::RedisIntegration

        Appsignal::Environment.report_enabled("redis")
      end
    end
  end
end
