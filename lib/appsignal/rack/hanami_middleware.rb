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

      def add_transaction_metadata_after(transaction, request)
        transaction.add_params { params_for(request) }
      end

      def params_for(request)
        ::Hanami::Action.params_class.new(request.env).to_h
      end
    end
  end
end
