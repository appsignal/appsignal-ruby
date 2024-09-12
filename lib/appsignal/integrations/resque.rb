# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ResqueIntegration
      def perform
        transaction = Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)

        Appsignal.instrument "perform.resque" do
          super
        end
      rescue Exception => exception # rubocop:disable Lint/RescueException
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

    # @api private
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
