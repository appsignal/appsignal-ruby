require 'net/http'

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

          def request(request, body=nil, &block)
            ActiveSupport::Notifications.instrument(
              'request.net_http',
              :protocol => use_ssl? ? 'https' : 'http',
              :domain   => request['host'] || self.address,
              :path     => request.path,
              :method   => request.method
            ) do
              request_without_appsignal(request, body, &block)
            end
          end
        end
      end
    end
  end
end
