module Appsignal
  class EventFormatter
    module NetHttp
      class RequestFormatter < Appsignal::EventFormatter
        register 'request.net_http'

        def format(payload)
          ["#{payload[:method]} #{payload[:url]}", nil]
        end
      end
    end
  end
end
