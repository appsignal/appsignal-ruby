# frozen_string_literal: true

module Appsignal
  # StreamWrapper used to be a special case, but now all Rack instrumentation supports
  # output streaming. The class is kept for backwards compatibility.
  #
  # @api private
  class StreamWrapper < Rack::GenericInstrumentation::EnumerableBodyWrapper
  end

  module Rack
    # Appsignal module that tracks exceptions in Streaming rack responses.
    #
    # @api private
    class StreamingListener < GenericInstrumentation
    end
  end
end
