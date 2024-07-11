# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ActionCableIntegration
      def perform_action(*args, &block)
        # The request is only the original websocket request
        env = connection.env
        request = ActionDispatch::Request.new(env)
        request_id = request.request_id || SecureRandom.uuid
        env[Appsignal::Hooks::ActionCableHook::REQUEST_ID] ||= request_id

        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::ACTION_CABLE,
          Appsignal::Transaction::GenericRequest.new({})
        )

        begin
          super
        rescue Exception => exception # rubocop:disable Lint/RescueException
          transaction.set_error(exception)
          raise exception
        ensure
          transaction.set_params_if_nil(args.first)
          transaction.set_action_if_nil("#{self.class}##{args.first["action"]}")
          transaction.set_metadata("path", request.path)
          transaction.set_metadata("method", "websocket")
          transaction.set_tags(:request_id => request_id) if request_id
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
