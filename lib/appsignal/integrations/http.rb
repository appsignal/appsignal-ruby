# frozen_string_literal: true

module Appsignal
  module Integrations
    module HttpIntegration
      def request(verb, uri, opts = {})
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::HTTP_REQUEST,
          Appsignal::Transaction::GenericRequest.new({})
        )

        begin
          Appsignal.instrument("request.http_rb", "#{verb.upcase} #{uri}") do
            super
          end
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          transaction.complete
        end
      end
    end
  end
end
