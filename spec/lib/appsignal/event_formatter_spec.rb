require 'spec_helper'

class MockFormatter < Appsignal::EventFormatter
  register 'mock'

  attr_reader :body

  def initialize
    @body = 'some value'
  end

  def format(payload)
    ['title', @body]
  end
end

class MockDependentFormatter < Appsignal::EventFormatter
  register 'mock.dependent'

  def initialize
    NonsenseDependency.something
  end
end

describe Appsignal::EventFormatter do
  before do
    Appsignal::EventFormatter.initialize_formatters
  end

  let(:klass) { Appsignal::EventFormatter }

  context "registering and unregistering formatters" do
    it "should register a formatter" do
      klass.formatters['mock'].should be_instance_of(MockFormatter)
    end

    it "should know wether a formatter is registered" do
      klass.registered?('mock').should be_true
      klass.registered?('mock', MockFormatter).should be_true
      klass.registered?('mock', Hash).should be_false
      klass.registered?('nonsense').should be_false
    end

    it "doesn't register formatters that raise a name error in the initializer" do
      klass.registered?('mock.dependent').should be_false
    end

    it "should register a custom formatter" do
      klass.register('mock.specific', MockFormatter)
      Appsignal::EventFormatter.initialize_formatters

      klass.formatter_classes['mock.specific'].should == MockFormatter
      klass.registered?('mock.specific').should be_true
      klass.formatters['mock.specific'].should be_instance_of(MockFormatter)
      klass.formatters['mock.specific'].body.should == 'some value'
    end

    it "should not have a formatter that's not registered" do
      klass.formatters['nonsense'].should be_nil
    end

    it "should unregister a formatter if the registered one has the same class" do
      klass.register('mock.unregister', MockFormatter)

      klass.unregister('mock.unregister', Hash)
      klass.registered?('mock.unregister').should be_true

      klass.unregister('mock.unregister', MockFormatter)
      klass.registered?('mock.unregister').should be_false
    end
  end

  context "calling formatters" do
    it "should return nil if there is no formatter registered" do
      klass.format('nonsense', {}).should == nil
    end

    it "should call the formatter if it is registered and use a value set in the initializer" do
      klass.format('mock', {}).should == ['title', 'some value']
    end
  end
end
