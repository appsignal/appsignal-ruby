# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module RedisIntegration
      def write(command)
        sanitized_command =
          if command[0] == :eval
            "#{command[1]}#{" ?" * (command.size - 3)}"
          else
            "#{command[0]}#{" ?" * (command.size - 1)}"
          end

        Appsignal.instrument(
          "query.redis",
          id,
          sanitized_command,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby-redis", Appsignal::VERSION]
        ) do
          super
        end
      end
    end
  end
end
