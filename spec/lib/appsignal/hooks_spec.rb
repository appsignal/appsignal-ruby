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
    expect(MockPresentHook).to receive(:call_something).once

    Appsignal::Hooks.register(:mock_present_hook, MockPresentHook)

    expect(Appsignal::Hooks.hooks[:mock_present_hook]).to be_instance_of(MockPresentHook)
    expect(Appsignal::Hooks.hooks[:mock_present_hook].installed?).to be_truthy

    Appsignal::Hooks.hooks.delete(:mock_present_hook)
  end

  it "should not install if depencies are not present" do
    expect(MockPresentHook).to_not receive(:call_something)

    Appsignal::Hooks.register(:mock_not_present_hook, MockNotPresentHook)

    expect(Appsignal::Hooks.hooks[:mock_not_present_hook]).to be_instance_of(MockNotPresentHook)
    expect(Appsignal::Hooks.hooks[:mock_not_present_hook].installed?).to be_falsy

    Appsignal::Hooks.hooks.delete(:mock_not_present_hook)
  end

  it "should not install if there is an error while installing" do
    expect(Appsignal.logger).to receive(:error).with("Error while installing mock_error_hook hook: error").once

    Appsignal::Hooks.register(:mock_error_hook, MockErrorHook)

    expect(Appsignal::Hooks.hooks[:mock_error_hook]).to be_instance_of(MockErrorHook)
    expect(Appsignal::Hooks.hooks[:mock_error_hook].installed?).to be_falsy

    Appsignal::Hooks.hooks.delete(:mock_error_hook)
  end
end

describe Appsignal::Hooks::Hook do
  let(:hook) do
    class MockDeprecatedHook < Appsignal::Hooks::Hook
      register :deprecated
      def dependencies_present?
        true
      end

      def install
        raise "error"
      end
    end
  end

  it "should log a deprecation warning when registering the hook in the deprecated way" do
    expect(Appsignal.logger).to receive(:error)
      .with("Hook for 'deprecated' is using a deprecated registration method." \
            "This hook will not be loaded" \
            "please update the hook according to the documentation at: " \
            "https://docs.appsignal.com/ruby/instrumentation/hooks.html"
      ).once

    hook
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

  describe "#extract_value" do
    context "for a hash" do
      let(:hash) { { :key => "value" } }

      context "when the key exists" do
        subject { with_helpers.extract_value(hash, :key) }

        it { is_expected.to eq "value" }
      end

      context "when the key does not exist" do
        subject { with_helpers.extract_value(hash, :nonexistent_key) }

        it { is_expected.to be_nil }

        context "with a default value" do
          subject { with_helpers.extract_value(hash, :nonexistent_key, 1) }

          it { is_expected.to eq 1 }
        end
      end
    end

    context "for a struct" do
      before :context do
        TestStruct = Struct.new(:key)
      end
      let(:struct) { TestStruct.new("value") }

      context "when the key exists" do
        subject { with_helpers.extract_value(struct, :key) }

        it { is_expected.to eq "value" }
      end

      context "when the key does not exist" do
        subject { with_helpers.extract_value(struct, :nonexistent_key) }

        it { is_expected.to be_nil }

        context "with a default value" do
          subject { with_helpers.extract_value(struct, :nonexistent_key, 1) }

          it { is_expected.to eq 1 }
        end
      end
    end

    context "for an object" do
      let(:object) { double(:existing_method => "value") }

      context "when the method exists" do
        subject { with_helpers.extract_value(object, :existing_method) }

        it { is_expected.to eq "value" }
      end

      context "when the method does not exist" do
        subject { with_helpers.extract_value(object, :nonexistent_method) }

        it { is_expected.to be_nil }

        context "and there is a default value" do
          subject { with_helpers.extract_value(object, :nonexistent_method, 1) }

          it { is_expected.to eq 1 }
        end
      end
    end

    context "when we need to call to_s on the value" do
      let(:object) { double(:existing_method => 1) }

      subject { with_helpers.extract_value(object, :existing_method, nil, true) }

      it { is_expected.to eq "1" }
    end
  end
end
