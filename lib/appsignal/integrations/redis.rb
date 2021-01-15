# frozen_string_literal: true

module Appsignal
  module Integrations
    module RedisIntegration
      def process(commands, &block)
        sanitized_commands = commands.map do |command, *args|
          "#{command}#{" ?" * args.size}"
        end.join("\n")

        Appsignal.instrument "query.redis", id, sanitized_commands do
          super
        end
      end
    end
  end
end
