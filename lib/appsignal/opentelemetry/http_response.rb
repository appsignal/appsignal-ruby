# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe an HTTP response.
    #
    # The semantic conventions ask for the response status code on the span of an
    # HTTP request, whether that is a request this application handled or one it
    # made. They ask for it only when a response was actually received or sent,
    # so a request that never got one is described without it.
    module HttpResponse
      STATUS_CODE_ATTRIBUTE = "http.response.status_code"

      class << self
        # The attributes describing the given response status, as a Hash to pass
        # to `add_opentelemetry_attributes`. Returns an empty Hash when there is
        # no status to describe, so a caller whose request produced no response
        # can pass the result on without checking.
        def attributes_for(status)
          code = Integer(status, :exception => false)
          return {} unless code

          { STATUS_CODE_ATTRIBUTE => code }
        end
      end
    end
  end
end
