# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module WebmachineIntegration
      def run
        has_parent_transaction = Appsignal::Transaction.current?
        transaction =
          if has_parent_transaction
            Appsignal::Transaction.current
          else
            # Read the incoming trace context off the request headers so the
            # transaction continues the upstream trace. No-op outside collector
            # mode. Webmachine isn't Rack: `request.headers` is a case-insensitive
            # `Webmachine::Headers`, so the default getter reads it directly.
            Appsignal::Transaction.create(
              Appsignal::Transaction::HTTP_REQUEST,
              :opentelemetry_context => Appsignal::OpenTelemetry.if_started do
                ::OpenTelemetry.propagation.extract(request.headers)
              end
            )
          end

        begin
          transaction.add_params_if_nil { request.query }
          transaction.add_headers_if_nil { request.headers if request.respond_to?(:headers) }

          Appsignal.instrument("process_action.webmachine") do
            super
          end
        ensure
          transaction.set_action_if_nil("#{resource.class.name}##{request.method}")

          Appsignal::Transaction.complete_current! unless has_parent_transaction
        end
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
