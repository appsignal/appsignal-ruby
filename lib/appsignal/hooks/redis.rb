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
        ::Redis::Client.class_eval do
          alias process_without_appsignal process

          def process(commands, &block)
            sanitized_commands = commands.map do |command, *args|
              "#{command}#{" ?" * args.size}"
            end.join("\n")

            Appsignal.instrument "query.redis", id, sanitized_commands do
              process_without_appsignal(commands, &block)
            end
          end
        end

        Appsignal::Environment.report_enabled("redis")
      end
    end
  end
end
