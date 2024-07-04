# frozen_string_literal: true

module Appsignal
  module Integrations
    module RakeIntegration
      def execute(*args)
        transaction =
          if Appsignal.config[:enable_rake_performance_instrumentation]
            _appsignal_create_transaction
          end

        Appsignal.instrument "task.rake" do
          super
        end
      rescue Exception => error # rubocop:disable Lint/RescueException
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
          Appsignal.stop("rake")
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
  end
end
