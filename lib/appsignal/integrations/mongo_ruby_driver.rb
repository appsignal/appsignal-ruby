module Appsignal
  class Hooks
    class MongoMonitorSubscriber

      # Called by Mongo::Monitor when query starts
      def started(event)
        return unless transaction = Appsignal::Transaction.current
        return if transaction.paused?

        # Store the query on the transaction, we need it when the event finishes
        store                   = transaction.store('mongo_driver')
        store[event.request_id] = Appsignal::Utils.sanitize(event.command)

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
        return unless transaction = Appsignal::Transaction.current
        return if transaction.paused?

        # Get the query from the transaction store
        store   = transaction.store('mongo_driver')
        command = store[event.request_id].inspect

        # Finish the event in the extension.
        Appsignal::Extension.finish_event(
          transaction.transaction_index,
          'query.mongodb',
          event.command_name.to_s,
          %Q(#{event.database_name} | #{result} | #{command})
        )
      end
    end

  end
end
