# frozen_string_literal: true

module Appsignal
  module Rack
    # @api private
    class HanamiMiddleware < AbstractMiddleware
      def initialize(app, options = {})
        options[:params_method] ||= :params
        options[:instrument_span_name] ||= "process_action.hanami"
        super
      end

      private

      def params_for(request)
        ::Hanami::Action.params_class.new(request.env).to_h
      end
    end
  end
end
