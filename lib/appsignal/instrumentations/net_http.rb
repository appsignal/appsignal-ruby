Net::HTTP.class_eval do
  alias request_without_appsignal request

  def request(request, body=nil, &block)
    ActiveSupport::Notifications.instrument(
      'request.net_http',
      :host => request['host'] || self.address,
      :scheme => use_ssl? ? 'https' : 'http',
      :path => request.path,
      :method => request.method
    ) do
      request_without_appsignal(request, body, &block)
    end
  end
end
