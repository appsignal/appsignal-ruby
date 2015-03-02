module Appsignal
  class EventFormatter
    module NetHttp
      class RequestFormatter < Appsignal::EventFormatter
        register 'request.net_http'

        def format(payload)
          ["#{payload[:method]} #{payload[:protocol]}://#{payload[:domain]}", nil]
        end
      end
    end
  end
end
