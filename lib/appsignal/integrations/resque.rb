# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ResqueIntegration
      def perform
        transaction = Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)

        Appsignal.instrument "perform.resque" do
          super
        end
      rescue Exception => exception
        transaction.set_error(exception)
        raise exception
      ensure
        if transaction
          transaction.set_action_if_nil("#{payload["class"]}#perform")
          transaction.add_params_if_nil { ResqueHelpers.arguments(payload) }
          transaction.add_tags("queue" => queue)

          Appsignal::Transaction.complete_current!
        end
        Appsignal.stop("resque")
      end
    end

    # Wraps `Resque.push` to record an `enqueue.resque` event so the enqueue
    # shows up under the active transaction.
    #
    # Like all AppSignal events, this only records when there's an active
    # transaction (e.g. enqueuing from within a web request or another job).
    # An enqueue with no transaction is a transparent pass-through.
    #
    # @!visibility private
    module ResquePushIntegration
      def push(_queue, _item)
        Appsignal.instrument("enqueue.resque") { super }
      end
    end

    # @!visibility private
    class ResqueHelpers
      def self.arguments(payload)
        case payload["class"]
        when "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
          nil # Set in the ActiveJob integration
        else
          payload["args"]
        end
      end
    end
  end
end
