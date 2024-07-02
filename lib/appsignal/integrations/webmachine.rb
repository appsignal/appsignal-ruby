# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module WebmachineIntegration
      def run
        has_parent_transaction = Appsignal::Transaction.current?
        transaction =
          if has_parent_transaction
            Appsignal::Transaction.current
          else
            Appsignal::Transaction.create(
              SecureRandom.uuid,
              Appsignal::Transaction::HTTP_REQUEST,
              request
            )
          end

        Appsignal.instrument("process_action.webmachine") do
          super
        end
      ensure
        transaction.set_action_if_nil("#{resource.class.name}##{request.method}")
        transaction.set_params_if_nil(request.query)

        Appsignal::Transaction.complete_current! unless has_parent_transaction
      end

      private

      def handle_exceptions
        super do
          yield
        rescue Exception => e # rubocop:disable Lint/RescueException
          Appsignal.set_error(e)
          raise e
        end
      end
    end
  end
end
