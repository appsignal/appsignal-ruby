# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module RakeIntegration
      IGNORED_ERRORS = [
        # Normal exits from the application we do not need to report
        SystemExit,
        SignalException
      ].freeze

      def self.ignored_error?(error)
        IGNORED_ERRORS.include?(error.class)
      end

      def execute(*args)
        transaction =
          if Appsignal.config[:enable_rake_performance_instrumentation]
            Appsignal::Integrations::RakeIntegrationHelper.register_at_exit_hook
            _appsignal_create_transaction
          end

        begin
          Appsignal.instrument(
            "task.rake",
            :opentelemetry_scope => ["appsignal-ruby/rake", Appsignal::VERSION]
          ) do
            super
          end
        rescue Exception => error
          Appsignal::Integrations::RakeIntegrationHelper.register_at_exit_hook
          unless RakeIntegration.ignored_error?(error)
            transaction ||= _appsignal_create_transaction
            transaction.set_error(error)
          end
          raise error
        ensure
          if transaction
            begin
              # Format given arguments and cast to hash if possible
              params, _ = args
              params = params.to_hash if params.respond_to?(:to_hash)
              transaction.set_action(name)
              transaction.add_request_payload_if_nil(params)
            rescue => metadata_error
              Appsignal.internal_logger.error(
                "Error finalizing transaction ##{transaction.transaction_id}: " \
                  "#{metadata_error.class}: #{metadata_error.message}"
              )
            ensure
              # Also unset it as the current transaction, so it is not reused by
              # code that runs after this task on the same thread.
              Appsignal::Transaction.complete_and_clear(transaction)
            end
          end
        end
      end

      private

      def _appsignal_create_transaction
        Appsignal::Transaction.create(
          "rake",
          :opentelemetry_scope => ["appsignal-ruby/rake", Appsignal::VERSION]
        )
      end
    end

    # @!visibility private
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
