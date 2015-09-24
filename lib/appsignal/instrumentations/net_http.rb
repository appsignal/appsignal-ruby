require 'net/http'

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
