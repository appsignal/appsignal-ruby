# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attribute that describes what kind of failure
    # ended an operation.
    #
    # The semantic conventions ask for `error.type` on a span whose operation
    # failed, and for it to be left unset on one that succeeded. The value has to
    # have low cardinality, which for an exception means its class name rather
    # than its message. A failure we have no name for becomes `_OTHER`, which is
    # the fallback the conventions define.
    module ErrorType
      ATTRIBUTE = "error.type"

      # The value the semantic conventions use for a failure the
      # instrumentation has no name for.
      OTHER = "_OTHER"

      class << self
        # The attributes describing the given failure, as a Hash to pass to
        # `add_opentelemetry_attributes`. Takes the name of the failure: an
        # exception's class name, or the error code a datastore reported.
        #
        # An anonymous exception class has no name, and a datastore does not
        # always report a code, so a missing name falls back to `_OTHER` rather
        # than leaving the span with no `error.type` at all.
        def attributes_for(name)
          value = name.to_s
          { ATTRIBUTE => value.empty? ? OTHER : value }
        end
      end
    end
  end
end
