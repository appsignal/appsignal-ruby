# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
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

        # Start this event
        transaction.start_event
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

        # Finish the event in the extension.
        transaction.finish_event(
          "query.mongodb",
          "#{event.command_name} | #{event.database_name} | #{result}",
          Appsignal::Utils::Data.generate(command),
          Appsignal::EventFormatter::DEFAULT
        )

        # Send global query metrics
        Appsignal.add_distribution_value(
          "mongodb_query_duration",
          event.duration,
          :database => event.database_name
        )
      end
    end
  end
end
