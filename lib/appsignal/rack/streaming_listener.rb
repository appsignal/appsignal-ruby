# frozen_string_literal: true

module Appsignal
  module Rack
    # Instrumentation middleware that tracks exceptions in streaming Rack
    # responses.
    #
    # @api private
    class StreamingListener < AbstractMiddleware
      def initialize(app, options = {})
        options[:instrument_event_name] ||= "process_streaming_request.rack"
        super
      end

      def add_transaction_metadata_after(transaction, request)
        transaction.set_action_if_nil(request.env["appsignal.action"])

        super
      end
    end
  end
end
