require 'spec_helper'
require File.expand_path('lib/appsignal/instrumentations/net_http')

describe "Net::HTTP instrumentation" do
  let(:events) { [] }
  before do
    ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  it "should generate an event for a http request" do
    stub_request(:any, 'http://www.google.com/')

    Net::HTTP.get_response(URI.parse('http://www.google.com'))

    event = events.last
    event.name.should == 'request.net_http'
    event.payload[:protocol].should == 'http'
    event.payload[:domain].should == 'www.google.com'
    event.payload[:path].should == '/'
    event.payload[:method].should == 'GET'
  end

  it "should generate an event for a https request" do
    stub_request(:any, 'https://www.google.com/')

    uri = URI.parse('https://www.google.com')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.get(uri.request_uri)

    event = events.last
    event.name.should == 'request.net_http'
    event.payload[:protocol].should == 'https'
    event.payload[:domain].should == 'www.google.com'
    event.payload[:path].should == '/'
    event.payload[:method].should == 'GET'
  end
end
