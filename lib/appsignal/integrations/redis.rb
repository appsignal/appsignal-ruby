# frozen_string_literal: true

module Appsignal
  module Integrations
    module RedisIntegration
      def write(command)
        sanitized_command = command[0] == :eval ? command[1] : "#{command[0]}#{" ?" * (command.size - 1)}"

        Appsignal.instrument "query.redis", id, sanitized_command do
          super
        end
      end
    end
  end
end
