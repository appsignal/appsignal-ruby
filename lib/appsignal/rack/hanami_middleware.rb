# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    class HanamiMiddleware < AbstractMiddleware
      def initialize(app, options = {})
        options[:params_method] = nil
        options[:instrument_event_name] ||= "process_action.hanami"
        super
      end

      private

      HANAMI_ACTION_INSTANCE = "hanami.action_instance"
      ROUTER_PARAMS = "router.params"

      def add_transaction_metadata_after(transaction, request)
        action_name = fetch_hanami_action(request.env)
        transaction.set_action_if_nil(action_name) if action_name
        transaction.add_params { params_for(request) }
      end

      def params_for(request)
        request.env.fetch(ROUTER_PARAMS, nil)
      end

      def fetch_hanami_action(env)
        # This env key is available in Hanami 2.2+
        action_instance = env.fetch(HANAMI_ACTION_INSTANCE, nil)
        return unless action_instance

        action_instance.class.name
      end
    end
  end
end
