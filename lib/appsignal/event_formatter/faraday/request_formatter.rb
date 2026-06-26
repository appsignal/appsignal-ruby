# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module Faraday
      class RequestFormatter
        def format(payload)
          http_method = payload[:method].to_s.upcase
          uri = payload[:url]
          # Empty body: the path is left out so the event matches Net::HTTP's
          # (scheme and host only), keeping paths out of event titles.
          ["#{http_method} #{uri.scheme}://#{uri.host}", ""]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "request.faraday",
  Appsignal::EventFormatter::Faraday::RequestFormatter
)
