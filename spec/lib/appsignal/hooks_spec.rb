require 'spec_helper'

class MockPresentHook < Appsignal::Hooks::Hook
  def dependencies_present?
    true
  end

  def install
    MockPresentHook.call_something
  end

  def self.call_something
  end
end

class MockNotPresentHook < Appsignal::Hooks::Hook
  def dependencies_present?
    false
  end

  def install
    MockNotPresentHook.call_something
  end
end

class MockErrorHook < Appsignal::Hooks::Hook
  def dependencies_present?
    true
  end

  def install
    raise 'error'
  end
end

describe Appsignal::Hooks do
  it "should register and install a hook once" do
    Appsignal::Hooks::Hook.register(:mock_present_hook, MockPresentHook)

    Appsignal::Hooks.hooks[:mock_present_hook].should be_instance_of(MockPresentHook)
    Appsignal::Hooks.hooks[:mock_present_hook].installed?.should be_false

    MockPresentHook.should_receive(:call_something).once

    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.hooks[:mock_present_hook].installed?.should be_true
  end

  it "should not install if depencies are not present" do
    Appsignal::Hooks::Hook.register(:mock_not_present_hook, MockNotPresentHook)

    Appsignal::Hooks.hooks[:mock_not_present_hook].should be_instance_of(MockNotPresentHook)
    Appsignal::Hooks.hooks[:mock_not_present_hook].installed?.should be_false

    MockPresentHook.should_not_receive(:call_something)

    Appsignal::Hooks.load_hooks

    Appsignal::Hooks.hooks[:mock_not_present_hook].installed?.should be_false
  end

  it "should not install if there is an error while installing" do
    Appsignal::Hooks::Hook.register(:mock_error_hook, MockErrorHook)

    Appsignal::Hooks.hooks[:mock_error_hook].should be_instance_of(MockErrorHook)
    Appsignal::Hooks.hooks[:mock_error_hook].installed?.should be_false

    Appsignal.logger.should_receive(:error).with("Error while installing mock_error_hook hook: error").once

    Appsignal::Hooks.load_hooks

    Appsignal::Hooks.hooks[:mock_error_hook].installed?.should be_false
  end
end

describe Appsignal::Hooks::Helpers do
  class ClassWithHelpers
    include Appsignal::Hooks::Helpers
  end

  let(:class_with_helpers) { ClassWithHelpers.new }

  describe "#truncate" do
    it "should call the class method helper" do
      expect( Appsignal::Hooks::Helpers ).to receive(:truncate).with('text')

      class_with_helpers.truncate('text')
    end
  end

  describe "#string_or_inspect" do
    it "should call the class method helper" do
      expect( Appsignal::Hooks::Helpers ).to receive(:string_or_inspect)
                                              .with('string')

      class_with_helpers.string_or_inspect('string')
    end
  end

  describe Appsignal::Hooks::Helpers::ClassMethods do
    describe "#truncate" do
      it "should call the class method helper" do
        expect( Appsignal::Hooks::Helpers ).to receive(:truncate).with('text')

        ClassWithHelpers.truncate('text')
      end
    end

    describe "#string_or_inspect" do
      it "should call the class method helper" do
        expect( Appsignal::Hooks::Helpers ).to receive(:string_or_inspect)
                                                .with('string')

        ClassWithHelpers.string_or_inspect('string')
      end
    end

    describe "#call_if_exists" do
      it "should call the class method helper" do
        expect( Appsignal::Hooks::Helpers ).to receive(:call_if_exists)
                                                .with('object', 'string', nil)

        ClassWithHelpers.call_if_exists('object', 'string')
      end

      it "should call the class method helper with a default value" do
        expect( Appsignal::Hooks::Helpers ).to receive(:call_if_exists)
                                                .with('object', 'string', 2)

        ClassWithHelpers.call_if_exists('object', 'string', 2)
      end
    end
  end

  describe ".truncate" do
    let(:very_long_text) do
      "a" * 400
    end

    it "should truncate the text to 200 chars max" do
      Appsignal::Hooks::Helpers.truncate(very_long_text).should == "#{'a' * 197}..."
    end
  end

  describe ".string_or_inspect" do
    context "when string" do
      it "should return the string" do
        Appsignal::Hooks::Helpers.string_or_inspect('foo').should == 'foo'
      end
    end

    context "when integer" do
      it "should return the string" do
        Appsignal::Hooks::Helpers.string_or_inspect(1).should == '1'
      end
    end

    context "when object" do
      let(:object) { Object.new }

      it "should return the string" do
        Appsignal::Hooks::Helpers.string_or_inspect(object).should == object.inspect
      end
    end
  end

  describe ".call_if_exists" do
    let(:object) { double(:existing_method => 'value') }

    context "when the method exists" do
      subject { Appsignal::Hooks::Helpers.call_if_exists(object, :existing_method) }

      it { should == 'value' }
    end

    context "when the method does not exist" do
      subject { Appsignal::Hooks::Helpers.call_if_exists(object, :nonexisting_method) }

      it { should be_nil }

      context "and there is a default value" do
        subject { Appsignal::Hooks::Helpers.call_if_exists(object, :nonexisting_method, 1) }

        it { should == 1 }
      end
    end
  end
end
