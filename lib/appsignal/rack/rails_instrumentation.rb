# frozen_string_literal: true

require "rack"

module Appsignal
  module Rack
    # @api private
    class RailsInstrumentation < Appsignal::Rack::AbstractMiddleware
      def initialize(app, options = {})
        options[:request_class] ||= ActionDispatch::Request
        options[:params_method] ||= :filtered_parameters
        options[:instrument_span_name] = nil
        options[:report_errors] = true
        super
      end

      private

      def add_transaction_metadata_after(transaction, request)
        controller = request.env["action_controller.instance"]
        transaction.set_action_if_nil("#{controller.class}##{controller.action_name}") if controller

        request_id = request.env["action_dispatch.request_id"]
        transaction.set_tags(:request_id => request_id) if request_id

        super
      end
    end
  end
end
