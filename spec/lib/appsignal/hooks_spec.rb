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

    expect(Appsignal.logger).to receive(:error)
      .with("Error while installing mock_error_hook hook: error").once
    expect(Appsignal.logger).to receive(:debug).ordered do |message|
      expect(message).to eq("Installing mock_error_hook hook")
    end
    expect(Appsignal.logger).to receive(:debug).ordered do |message|
      # Start of the error backtrace as debug log
      expect(message).to start_with(File.expand_path("../../..", __dir__))
    end

    Appsignal::Hooks.load_hooks

    expect(Appsignal::Hooks.hooks[:mock_error_hook].installed?).to be_falsy
    Appsignal::Hooks.hooks.delete(:mock_error_hook)
  end

  describe "missing constants" do
    let(:err_stream) { std_stream }
    let(:stderr) { err_stream.read }
    let(:log_stream) { std_stream }
    let(:log) { log_contents(log_stream) }
    before do
      Appsignal.logger = test_logger(log_stream)
    end

    def call_constant(&block)
      capture_std_streams(std_stream, err_stream, &block)
    end

    describe "SidekiqPlugin" do
      it "logs a deprecation message and returns the new constant" do
        constant = call_constant { Appsignal::Hooks::SidekiqPlugin }

        expect(constant).to eql(Appsignal::Integrations::SidekiqMiddleware)
        expect(constant.name).to eql("Appsignal::Integrations::SidekiqMiddleware")

        deprecation_message =
          "The constant Appsignal::Hooks::SidekiqPlugin has been deprecated. " \
            "Please update the constant name to Appsignal::Integrations::SidekiqMiddleware " \
            "in the following file to remove this message.\n#{__FILE__}:"
        expect(stderr).to include "appsignal WARNING: #{deprecation_message}"
        expect(log).to contains_log :warn, deprecation_message
      end
    end

    describe "other constant" do
      it "raises a NameError like Ruby normally does" do
        expect do
          call_constant { Appsignal::Hooks::Unknown }
        end.to raise_error(NameError)

        expect(stderr).to be_empty
        expect(log).to be_empty
      end
    end
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
