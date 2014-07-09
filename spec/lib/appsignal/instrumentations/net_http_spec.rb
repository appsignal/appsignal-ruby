require 'spec_helper'
require File.expand_path('lib/appsignal/instrumentations/net_http')

describe "Net::HTTP instrumentation" do
  let(:events) { [] }
  before do
    ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  it "should instrument request" do
    Net::HTTP.any_instance.should_receive(:request_without_appsignal)

    Net::HTTP.get_response(URI.parse('http://www.google.com/robots.txt'))

    event = events.last
    event.name.should == 'request.net_http'
    event.payload[:host].should == 'www.google.com'
    event.payload[:scheme].should == 'http'
    event.payload[:path].should == '/robots.txt'
    event.payload[:method].should == 'GET'
  end
end
