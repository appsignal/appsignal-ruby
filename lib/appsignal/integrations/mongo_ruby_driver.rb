module Appsignal
  class Hooks
    class MongoMonitorSubscriber
      # Called by Mongo::Monitor when query starts
      def started(event)
        transaction = Appsignal::Transaction.current
        return if transaction.nil_transaction?
        return if transaction.paused?

        # Format the command
        command = Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter
          .format(event.command_name, event.command)

        # Store the query on the transaction, we need it when the event finishes
        store                   = transaction.store('mongo_driver')
        store[event.request_id] = command

        # Start this event
        Appsignal::Extension.start_event(transaction.transaction_index)
      end

      # Called by Mongo::Monitor when query succeeds
      def succeeded(event)
        # Finish the event as succeeded
        finish('SUCCEEDED', event)
      end

      # Called by Mongo::Monitor when query fails
      def failed(event)
        # Finish the event as failed
        finish('FAILED', event)
      end

      # Finishes the event in the AppSignal extension
      def finish(result, event)
        transaction = Appsignal::Transaction.current
        return if transaction.nil_transaction?
        return if transaction.paused?

        # Get the query from the transaction store
        store   = transaction.store('mongo_driver')
        command = store.delete(event.request_id) || {}

        # Finish the event in the extension.
        Appsignal::Extension.finish_event(
          transaction.transaction_index,
          'query.mongodb',
          "#{event.command_name.to_s} | #{event.database_name} | #{result}",
          Appsignal::Utils.json_generate(command),
          0
        )
      end
    end

  end
end
