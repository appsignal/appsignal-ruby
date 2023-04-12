# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module WebmachineIntegration
      def run
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :query
        )

        transaction.set_action_if_nil("#{resource.class.name}##{request.method}")

        Appsignal.instrument("process_action.webmachine") do
          super
        end

        Appsignal::Transaction.complete_current!
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
