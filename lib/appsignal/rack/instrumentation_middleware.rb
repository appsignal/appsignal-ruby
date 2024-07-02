# frozen_string_literal: true

module Appsignal
  module Rack
    # @api public
    class InstrumentationMiddleware < AbstractMiddleware
      def initialize(app, options = {})
        options[:instrument_span_name] ||= "process_request_middleware.rack"
        super
      end
    end
  end
end
