# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe an HTTP request method.
    #
    # The semantic conventions treat `http.request.method` as a closed set of
    # known method names, so an arbitrary value cannot be passed through. A
    # method outside the set becomes `_OTHER`, and a method that only matches
    # after upcasing is replaced by its canonical form. Both of those cases keep
    # the value we were given in `http.request.method_original`, so the original
    # is never lost.
    module HttpMethod
      # The methods the semantic conventions know about: those defined in
      # RFC 9110, plus PATCH from RFC 5789.
      KNOWN_METHODS = [
        "CONNECT",
        "DELETE",
        "GET",
        "HEAD",
        "OPTIONS",
        "PATCH",
        "POST",
        "PUT",
        "TRACE"
      ].freeze

      # The value the semantic conventions use for a method they do not know.
      OTHER = "_OTHER"

      METHOD_ATTRIBUTE = "http.request.method"
      ORIGINAL_ATTRIBUTE = "http.request.method_original"

      class << self
        # The attributes describing the given request method, as a Hash to pass
        # to `add_opentelemetry_attributes`. Returns an empty Hash when there is
        # no method to describe, so a caller that could not read one can pass
        # the result on without checking.
        def attributes_for(method)
          original = method.to_s
          return {} if original.empty?

          # Method names are case sensitive, so a value that already matches a
          # known method is used as it is, with nothing to preserve.
          return { METHOD_ATTRIBUTE => original } if KNOWN_METHODS.include?(original)

          canonical = original.upcase
          if KNOWN_METHODS.include?(canonical)
            { METHOD_ATTRIBUTE => canonical, ORIGINAL_ATTRIBUTE => original }
          else
            { METHOD_ATTRIBUTE => OTHER, ORIGINAL_ATTRIBUTE => original }
          end
        end
      end
    end
  end
end
