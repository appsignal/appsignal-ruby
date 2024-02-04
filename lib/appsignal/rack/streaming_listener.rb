# frozen_string_literal: true

module Appsignal
  module Rack
    # Appsignal module that tracks exceptions in Streaming rack responses.
    #
    # @api private
    class StreamingListener < GenericInstrumentation
    end
  end
end
