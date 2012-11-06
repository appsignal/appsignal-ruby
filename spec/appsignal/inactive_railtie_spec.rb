require 'spec_helper'

describe "Inactive Appsignal::Railtie" do

  before do
    Appsignal.stub(:active => false)
    MyApp::Application.initialize!
  end

  it "should not insert itself into the middleware stack" do
    MyApp::Application.middleware.to_a.should_not include Appsignal::Middleware
  end

end
