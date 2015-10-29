require 'net/http'

Net::HTTP.class_eval do
  alias request_without_appsignal request

  def request(request, body=nil, &block)
    Appsignal.instrument(
      'request.net_http',
      "#{request.method} #{use_ssl? ? 'https' : 'http'}://#{request['host'] || self.address}"
    ) do
      request_without_appsignal(request, body, &block)
    end
  end
end
