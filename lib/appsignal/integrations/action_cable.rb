# frozen_string_literal: true

module Appsignal
  module Integrations
    module ActionCableIntegration
      def perform_action(*args, &block)
        # The request is only the original websocket request
        env = connection.env
        request = ActionDispatch::Request.new(env)
        env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||=
          request.request_id || SecureRandom.uuid

        transaction = Appsignal::Transaction.create(
          env[Appsignal::Hooks::ActionCableHook::REQUEST_ID],
          Appsignal::Transaction::ACTION_CABLE,
          request
        )

        begin
          super
        rescue Exception => exception # rubocop:disable Lint/RescueException
          transaction.set_error(exception)
          raise exception
        ensure
          transaction.params = args.first
          transaction.set_action_if_nil("#{self.class}##{args.first["action"]}")
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", "websocket")
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
