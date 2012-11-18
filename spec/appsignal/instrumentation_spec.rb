require 'spec_helper'
require 'appsignal/instrumentation/mongo'
require 'appsignal/instrumentation/tire'

describe "Setting up instrumentation" do
  it "should setup instrumentation" do
    Appsignal::MongoInstrumentation.should_receive(:setup)
    Appsignal::TireInstrumentation.should_receive(:setup)

    require 'appsignal/instrumentation'
  end
end
