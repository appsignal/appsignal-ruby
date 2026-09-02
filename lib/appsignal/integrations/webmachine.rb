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
              end,
              :opentelemetry_scope => ["appsignal-ruby/webmachine", Appsignal::VERSION]
            )
          end

        unless has_parent_transaction
          # Describes the transaction's span as an incoming HTTP request.
          # Together with the SERVER span kind the transaction already carries,
          # this is what the trace timeline reads to recognize a web request.
          # Set here, where the transaction is created, so they land on the
          # transaction's own span rather than on the event started below.
          #
          # Webmachine isn't Rack: the path, scheme, query string, host and port
          # come off the request's `URI` rather than from Rack's readers. The
          # request's own `query` is the parsed form, so the URI is where the
          # string itself is. Webmachine has no environment to read the protocol
          # version from, so that one is left undescribed.
          transaction.add_opentelemetry_attributes(
            Appsignal::OpenTelemetry::HttpServerRequest.attributes_for(
              :method => request.method,
              :path => request.uri&.path,
              :scheme => request.uri&.scheme,
              :query => request.uri&.query,
              :host => request.uri&.host,
              :port => request.uri&.port
            )
          )
        end

        begin
          transaction.add_query_parameters_if_nil { request.query }
          transaction.add_headers_if_nil { request.headers if request.respond_to?(:headers) }

          Appsignal.instrument(
            "process_action.webmachine",
            :opentelemetry_scope => ["appsignal-ruby/webmachine", Appsignal::VERSION]
          ) do
            super
          end
        ensure
          transaction.set_action_if_nil("#{resource.class.name}##{request.method}")

          unless has_parent_transaction
            # Describes the response on the transaction's span, which the
            # semantic conventions ask for whenever a response was sent. The
            # event above has closed by now, so this lands on the transaction's
            # own span.
            transaction.add_opentelemetry_attributes(
              Appsignal::OpenTelemetry::HttpResponse.attributes_for(response.code)
            )

            Appsignal::Transaction.complete_current!
          end
        end
      end

      private

      def handle_exceptions
        super do
          yield
        rescue Exception => e
          Appsignal.set_error(e)
          raise e
        end
      end
    end
  end
end
