# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class RedisClientHook < Appsignal::Hooks::Hook
      register :redis_client

      def dependencies_present?
        defined?(::RedisClient) &&
          Appsignal.config &&
          Appsignal.config[:instrument_redis]
      end

      def install
        require "appsignal/integrations/redis_client"
        ::RedisClient::RubyConnection.prepend Appsignal::Integrations::RedisClientIntegration
        Appsignal::Environment.report_enabled("redis")

        return unless defined?(::RedisClient::HiredisConnection)

        ::RedisClient::HiredisConnection.prepend Appsignal::Integrations::RedisClientIntegration
        Appsignal::Environment.report_enabled("hiredis")
      end
    end
  end
end
