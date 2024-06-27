# frozen_string_literal: true

require "appsignal"
require "appsignal/rack/grape_middleware"

Appsignal.internal_logger.debug("Loading Grape integration")

module Appsignal
  # @api private
  module Grape
    # Alias constants that have moved with a warning message that points to the
    # place to update the reference.
    def self.const_missing(name)
      case name
      when :Middleware
        callers = caller
        Appsignal::Utils::StdoutAndLoggerMessage.warning \
          "The constant Appsignal::Grape::Middleware has been deprecated. " \
            "Please update the constant name to " \
            "Appsignal::Rack::GrapeMiddleware in the following file to " \
            "remove this message.\n#{callers.first}"
        Appsignal::Rack::GrapeMiddleware
      else
        super
      end
    end
  end
end
