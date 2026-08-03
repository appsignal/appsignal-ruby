# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module RedisClientIntegration
      def write(command)
        sanitized_command =
          if command[0] == :eval
            "#{command[1]}#{" ?" * (command.size - 3)}"
          else
            "#{command[0]}#{" ?" * (command.size - 1)}"
          end
        operation_name = command[0].to_s

        Appsignal.instrument(
          "query.redis",
          @config.id,
          sanitized_command,
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/redis_client", Appsignal::VERSION]
        ) do
          # Names the datastore this span talks to, which is what the trace
          # timeline reads to recognize a cache call, along with the command and
          # the database it ran against.
          #
          # The command stays in the event body rather than moving to
          # `db.query.text`: it is sanitized here already, and the collector
          # sanitizes `db.query.text` again for Redis, which would mangle it.
          Appsignal::Transaction.current.add_opentelemetry_attributes(
            {
              "db.system.name" => "redis",
              "db.operation.name" => (operation_name unless operation_name.empty?),
              "db.namespace" => (@config.db.to_s if @config.respond_to?(:db) && @config.db)
            }.compact
          )
          super
        end
      end
    end
  end
end
