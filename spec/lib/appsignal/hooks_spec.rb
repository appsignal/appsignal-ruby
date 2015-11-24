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
