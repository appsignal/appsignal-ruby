# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module RakeIntegration
      def execute(*args)
        transaction =
          if Appsignal.config[:enable_rake_performance_instrumentation]
            Appsignal::Integrations::RakeIntegrationHelper.register_at_exit_hook
            _appsignal_create_transaction
          end

        Appsignal.instrument "task.rake" do
          super
        end
      rescue Exception => error # rubocop:disable Lint/RescueException
        Appsignal::Integrations::RakeIntegrationHelper.register_at_exit_hook
        transaction ||= _appsignal_create_transaction
        transaction.set_error(error)
        raise error
      ensure
        if transaction
          # Format given arguments and cast to hash if possible
          params, _ = args
          params = params.to_hash if params.respond_to?(:to_hash)
          transaction.set_params_if_nil(params)
          transaction.set_action(name)
          transaction.complete
        end
      end

      private

      def _appsignal_create_transaction
        Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new({})
        )
      end
    end

    # @api private
    module RakeIntegrationHelper
      # Register an `at_exit` hook when a task is executed. This will stop
      # AppSignal when _all_ tasks are executed and Rake exits.
      def self.register_at_exit_hook
        return if @register_at_exit_hook

        Kernel.at_exit(&method(:at_exit_hook))

        @register_at_exit_hook = true
      end

      # The at_exit hook itself
      def self.at_exit_hook
        Appsignal.stop("rake")
      end
    end
  end
end
