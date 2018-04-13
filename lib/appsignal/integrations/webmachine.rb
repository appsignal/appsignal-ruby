# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module WebmachinePlugin
      module FSM
        def run_with_appsignal
          transaction = Appsignal::Transaction.create(
            SecureRandom.uuid,
            Appsignal::Transaction::HTTP_REQUEST,
            request,
            :params_method => :query
          )

          transaction.set_action_if_nil("#{resource.class.name}##{request.method}")

          Appsignal.instrument("process_action.webmachine") do
            run_without_appsignal
          end

          Appsignal::Transaction.complete_current!
        end

        private

        def handle_exceptions_with_appsignal
          handle_exceptions_without_appsignal do
            begin
              yield
            rescue Exception => e # rubocop:disable Lint/RescueException
              Appsignal.set_error(e)
              raise e
            end
          end
        end
      end
    end
  end
end
