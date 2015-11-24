require 'spec_helper'
require File.expand_path('lib/appsignal/instrumentations/object')

describe "Object custom instrumentation methods" do
  let(:events) { [] }
  before do
    ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  it "should instrument my method" do
    result = TestClass.new.my_method
    result.should == "peanuts"

    event = events.last
    event.name.should == 'TestClass.my_method'
  end

  it "should instrument within a method" do
    result = TestClass.new.my_other_method
    result.should == "peanuts"

    event = events.last
    event.name.should == 'TestClass.measure.bananas'
  end

  class TestClass
    def my_method
      "peanuts"
    end
    measure :my_method

    def my_other_method
      measure "bananas" do
        "peanuts"
      end
    end
  end
end
