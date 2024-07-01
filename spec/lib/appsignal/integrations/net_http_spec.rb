require "appsignal/integrations/net_http"

describe Appsignal::Integrations::NetHttpIntegration do
  let(:transaction) { http_request_transaction }
  before(:context) { start_agent }
  before { set_current_transaction transaction }
  around { |example| keep_transactions { example.run } }

  it "instruments a http request" do
    stub_request(:any, "http://www.google.com/")

    Net::HTTP.get_response(URI.parse("http://www.google.com"))

    expect(transaction).to include_event(
      "name" => "request.net_http",
      "title" => "GET http://www.google.com"
    )
  end

  it "instruments a https request" do
    stub_request(:any, "https://www.google.com/")

    uri = URI.parse("https://www.google.com")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri.request_uri)

    expect(transaction).to include_event(
      "name" => "request.net_http",
      "title" => "GET https://www.google.com"
    )
  end
end
