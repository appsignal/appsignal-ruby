# frozen_string_literal: true

module Appsignal
  module Integrations
    module RakeIntegration
      def execute(*args)
        super
      rescue Exception => error # rubocop:disable Lint/RescueException
        # Format given arguments and cast to hash if possible
        params, _ = args
        params = params.to_hash if params.respond_to?(:to_hash)

        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new(
            :params => params
          )
        )
        transaction.set_action(name)
        transaction.set_error(error)
        transaction.complete
        Appsignal.stop("rake")
        raise error
      end
    end
  end
end
