# frozen_string_literal: true

module Appsignal
  # StreamWrapper used to be a special case, but now all Rack instrumentation supports
  # output streaming. The class is kept for backwards compatibility.
  #
  # @api private
  StreamWrapper = Rack::EnumerableBodyWrapper

  module Rack
    # Used to be the module that tracks exceptions in streaming rack responses,
    # but is in fact the same as the standard Rack instrumentation
    #
    # @api private
    StreamingListener = GenericInstrumentation
  end
end
