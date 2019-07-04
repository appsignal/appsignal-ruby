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
    raise "error"
  end
end

describe Appsignal::Hooks do
  it "should register and install a hook once" do
    Appsignal::Hooks::Hook.register(:mock_present_hook, MockPresentHook)

    expect(Appsignal::Hooks.hooks[:mock_present_hook]).to be_instance_of(MockPresentHook)
    expect(Appsignal::Hooks.hooks[:mock_present_hook].installed?).to be_falsy

    expect(MockPresentHook).to receive(:call_something).once

    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    expect(Appsignal::Hooks.hooks[:mock_present_hook].installed?).to be_truthy
    Appsignal::Hooks.hooks.delete(:mock_present_hook)
  end

  it "should not install if depencies are not present" do
    Appsignal::Hooks::Hook.register(:mock_not_present_hook, MockNotPresentHook)

    expect(Appsignal::Hooks.hooks[:mock_not_present_hook]).to be_instance_of(MockNotPresentHook)
    expect(Appsignal::Hooks.hooks[:mock_not_present_hook].installed?).to be_falsy

    expect(MockPresentHook).to_not receive(:call_something)

    Appsignal::Hooks.load_hooks

    expect(Appsignal::Hooks.hooks[:mock_not_present_hook].installed?).to be_falsy
    Appsignal::Hooks.hooks.delete(:mock_not_present_hook)
  end

  it "should not install if there is an error while installing" do
    Appsignal::Hooks::Hook.register(:mock_error_hook, MockErrorHook)

    expect(Appsignal::Hooks.hooks[:mock_error_hook]).to be_instance_of(MockErrorHook)
    expect(Appsignal::Hooks.hooks[:mock_error_hook].installed?).to be_falsy

    expect(Appsignal.logger).to receive(:error).with("Error while installing mock_error_hook hook: error").once
    expect(Appsignal.logger).to receive(:debug).once do |message|
      # Start of the error backtrace as debug log
      expect(message).to start_with(File.expand_path("../../../../", __FILE__))
    end

    Appsignal::Hooks.load_hooks

    expect(Appsignal::Hooks.hooks[:mock_error_hook].installed?).to be_falsy
    Appsignal::Hooks.hooks.delete(:mock_error_hook)
  end
end

describe Appsignal::Hooks::Helpers do
  class ClassWithHelpers
    include Appsignal::Hooks::Helpers
  end
  let(:with_helpers) { ClassWithHelpers.new }

  describe "#truncate" do
    let(:very_long_text) do
      "a" * 400
    end

    it "should truncate the text to 200 chars max" do
      expect(with_helpers.truncate(very_long_text)).to eq "#{"a" * 197}..."
    end
  end

  describe "#string_or_inspect" do
    context "when string" do
      it "should return the string" do
        expect(with_helpers.string_or_inspect("foo")).to eq "foo"
      end
    end

    context "when integer" do
      it "should return the string" do
        expect(with_helpers.string_or_inspect(1)).to eq "1"
      end
    end

    context "when object" do
      let(:object) { Object.new }

      it "should return the string" do
        expect(with_helpers.string_or_inspect(object)).to eq object.inspect
      end
    end
  end
end
