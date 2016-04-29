module Appsignal
  class EventFormatter
    module Faraday
      class RequestFormatter < Appsignal::EventFormatter
        register 'request.faraday'

        def format(payload)
          ["#{payload[:method].to_s.upcase} #{payload[:url]}", nil]
        end
      end
    end
  end
end
