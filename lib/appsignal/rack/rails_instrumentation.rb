# frozen_string_literal: true

require "rack"

module Appsignal
  # @api private
  module Rack
    class RailsInstrumentation
      def initialize(app, options={})
        super
        @options[:request_class] = ActionDispatch::Request
        @instrument_span_name = "process_action.rails"
      end

      def set_transaction_attributes_from_request(transaction, request)
        controller = request.env["action_controller.instance"]
        if controller
          transaction.set_action_if_nil("#{controller.class}##{controller.action_name}")
        end
        super
      end

      def create_transaction_from_request(request)
        Appsignal::Transaction.create(
          request_id(request.env),
          Appsignal::Transaction::HTTP_REQUEST,
          request,
          :params_method => :filtered_parameters
        )
      end

      def request_id(env)
        env["action_dispatch.request_id"] || SecureRandom.uuid
      end
    end
  end
end
