require "net/http"

module Appsignal
  class Hooks
    class NetHttpHook < Appsignal::Hooks::Hook
      register :net_http

      def dependencies_present?
        Appsignal.config && Appsignal.config[:instrument_net_http]
      end

      def install
        Net::HTTP.class_eval do
          alias request_without_appsignal request

          def request(request, body = nil, &block)
            Appsignal.instrument(
              "request.net_http",
              "#{request.method} #{use_ssl? ? "https" : "http"}://#{request["host"] || self.address}"
            ) do
              request_without_appsignal(request, body, &block)
            end
          end
        end
      end
    end
  end
end
