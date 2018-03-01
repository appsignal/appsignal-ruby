# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module Faraday
      class RequestFormatter < Appsignal::EventFormatter
        register "request.faraday"

        def format(payload)
          http_method = payload[:method].to_s.upcase
          uri = payload[:url]
          [
            "#{http_method} #{uri.scheme}://#{uri.host}",
            "#{http_method} #{uri.scheme}://#{uri.host}#{uri.path}"
          ]
        end
      end
    end
  end
end
