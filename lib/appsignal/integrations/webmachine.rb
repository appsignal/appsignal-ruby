module Appsignal::Integrations
  module WebmachinePlugin
    module FSM

      def run_with_appsignal
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          {:params_method => :query}
        )

        transaction.set_action("#{resource.class.name}##{request.method}")

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
          rescue => e
            Appsignal.set_error(e)
            raise e
          end
        end
      end
    end
  end
end
