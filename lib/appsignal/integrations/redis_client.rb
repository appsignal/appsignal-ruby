# frozen_string_literal: true

module Appsignal
  module Integrations
    module RedisClientIntegration
      def write(command)
        sanitized_command =
          if command[0] == :eval
            "#{command[1]}#{" ?" * (command.size - 3)}"
          else
            "#{command[0]}#{" ?" * (command.size - 1)}"
          end

        Appsignal.instrument "query.redis", @config.id, sanitized_command do
          super
        end
      end
    end
  end
end
