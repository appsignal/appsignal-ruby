# frozen_string_literal: true

require "json"

module Appsignal
  class Hooks
    # @!visibility private
    class MongoMonitorSubscriber
      # Called by Mongo::Monitor when query starts
      def started(event)
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        return if transaction.paused?

        # Format the command
        command = Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter
          .format(event.command_name, event.command)

        # Store the query on the transaction, we need it when the event finishes
        store                   = transaction.store("mongo_driver")
        store[event.request_id] = command

        # Start this event. The query is an outgoing client call.
        transaction.start_event(
          :opentelemetry_kind => :client,
          :opentelemetry_scope => ["appsignal-ruby/mongo", Appsignal::VERSION]
        )
        # Names the datastore this span talks to, which is what the trace
        # timeline reads to recognize a database call, along with the command
        # that ran, what it ran against, and the server it went to. Set here,
        # where the event span it describes is the open one.
        transaction.add_opentelemetry_attributes(
          {
            "db.system.name" => "mongodb",
            "db.operation.name" => event.command_name,
            "db.collection.name" => collection_name(event),
            "db.namespace" => event.database_name,
            "server.address" => event.address&.host,
            "server.port" => event.address&.port
          }.compact
        )
      end

      # Called by Mongo::Monitor when query succeeds
      def succeeded(event)
        # Finish the event as succeeded
        finish("SUCCEEDED", event)
      end

      # Called by Mongo::Monitor when query fails
      def failed(event)
        # Finish the event as failed
        finish("FAILED", event)
      end

      # Finishes the event in the AppSignal extension
      def finish(result, event)
        return unless Appsignal::Transaction.current?

        transaction = Appsignal::Transaction.current
        return if transaction.paused?

        # Get the query from the transaction store
        store   = transaction.store("mongo_driver")
        command = store.delete(event.request_id) || {}

        # Say what kind of failure ended the query, which the OpenTelemetry
        # semantic conventions ask for on a span whose operation failed. The
        # driver reports a failure by calling us rather than by raising, so this
        # is the only place it can be read. Set before the event is finished, so
        # it lands on the query's own span.
        #
        # Only a failure event carries a failure, which is what tells the two
        # apart here.
        if event.respond_to?(:failure)
          transaction.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::ErrorType.attributes_for(error_name(event.failure))
          )
          # MongoDB's own code for the error, which the conventions ask for
          # whenever the database reported one.
          transaction.add_opentelemetry_attributes(
            { "db.response.status_code" => error_code(event.failure) }.compact
          )
        end

        # Finish the event. The sanitized command is a (nested) Hash; emit it
        # as a JSON string so it works with both transaction backends. The
        # agent serializes structured bodies to JSON anyway, so this is
        # equivalent output there, and the collector receives a plain string.
        transaction.finish_event(
          "query.mongodb",
          "#{event.command_name} | #{event.database_name} | #{result}",
          Appsignal::Utils::JSON.generate(command),
          Appsignal::EventFormatter::DEFAULT
        )

        # Send global query metrics
        Appsignal.add_distribution_value(
          "mongodb_query_duration",
          event.duration,
          :database => event.database_name
        )
      end

      private

      # The collection a command worked on. MongoDB puts it in the field named
      # after the command itself, as in `{ "find" => "users" }`. A command that
      # works on the database as a whole rather than on one collection has
      # something else in that field, such as the number 1, so only a String
      # counts as a collection name.
      def collection_name(event)
        return unless event.command.respond_to?(:[])

        collection = event.command[event.command_name]
        collection if collection.is_a?(String)
      end

      # MongoDB's own code for an error, which it puts in the `code` field of the
      # error document it replies with. Reported as a String, which is what the
      # conventions ask for.
      def error_code(failure)
        return unless failure.respond_to?(:[])

        failure["code"]&.to_s
      end

      # MongoDB names an error in the `codeName` field of the error document it
      # replies with. A failure the driver never got a document for, such as a
      # connection that dropped, has no name.
      def error_name(failure)
        failure["codeName"] if failure.respond_to?(:[])
      end
    end
  end
end
