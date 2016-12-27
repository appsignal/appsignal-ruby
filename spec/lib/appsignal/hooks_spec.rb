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

    Appsignal::Hooks.hooks[:mock_present_hook].should be_instance_of(MockPresentHook)
    Appsignal::Hooks.hooks[:mock_present_hook].installed?.should be_false

    MockPresentHook.should_receive(:call_something).once

    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.load_hooks
    Appsignal::Hooks.hooks[:mock_present_hook].installed?.should be_true
    Appsignal::Hooks.hooks.delete(:mock_present_hook)
  end

  it "should not install if depencies are not present" do
    Appsignal::Hooks::Hook.register(:mock_not_present_hook, MockNotPresentHook)

    Appsignal::Hooks.hooks[:mock_not_present_hook].should be_instance_of(MockNotPresentHook)
    Appsignal::Hooks.hooks[:mock_not_present_hook].installed?.should be_false

    MockPresentHook.should_not_receive(:call_something)

    Appsignal::Hooks.load_hooks

    Appsignal::Hooks.hooks[:mock_not_present_hook].installed?.should be_false
    Appsignal::Hooks.hooks.delete(:mock_not_present_hook)
  end

  it "should not install if there is an error while installing" do
    Appsignal::Hooks::Hook.register(:mock_error_hook, MockErrorHook)

    Appsignal::Hooks.hooks[:mock_error_hook].should be_instance_of(MockErrorHook)
    Appsignal::Hooks.hooks[:mock_error_hook].installed?.should be_false

    Appsignal.logger.should_receive(:error).with("Error while installing mock_error_hook hook: error").once

    Appsignal::Hooks.load_hooks

    Appsignal::Hooks.hooks[:mock_error_hook].installed?.should be_false
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
      with_helpers.truncate(very_long_text).should eq "#{"a" * 197}..."
    end
  end

  describe "#string_or_inspect" do
    context "when string" do
      it "should return the string" do
        with_helpers.string_or_inspect("foo").should eq "foo"
      end
    end

    context "when integer" do
      it "should return the string" do
        with_helpers.string_or_inspect(1).should eq "1"
      end
    end

    context "when object" do
      let(:object) { Object.new }

      it "should return the string" do
        with_helpers.string_or_inspect(object).should eq object.inspect
      end
    end
  end

  describe "#extract_value" do
    context "for a hash" do
      let(:hash) { {:key => "value"} }

      context "when the key exists" do
        subject { with_helpers.extract_value(hash, :key) }

        it { should eq "value" }
      end

      context "when the key does not exist" do
        subject { with_helpers.extract_value(hash, :nonexistent_key) }

        it { should be_nil }

        context "with a default value" do
          subject { with_helpers.extract_value(hash, :nonexistent_key, 1) }

          it { should eq 1 }
        end
      end
    end

    context "for a struct" do
      before :all do
        TestStruct = Struct.new(:key)
      end
      let(:struct) { TestStruct.new("value") }

      context "when the key exists" do
        subject { with_helpers.extract_value(struct, :key) }

        it { should eq "value" }
      end

      context "when the key does not exist" do
        subject { with_helpers.extract_value(struct, :nonexistent_key) }

        it { should be_nil }

        context "with a default value" do
          subject { with_helpers.extract_value(struct, :nonexistent_key, 1) }

          it { should eq 1 }
        end
      end
    end

    context "for an object" do
      let(:object) { double(:existing_method => "value") }

      context "when the method exists" do
        subject { with_helpers.extract_value(object, :existing_method) }

        it { should eq "value" }
      end

      context "when the method does not exist" do
        subject { with_helpers.extract_value(object, :nonexistent_method) }

        it { should be_nil }

        context "and there is a default value" do
          subject { with_helpers.extract_value(object, :nonexistent_method, 1) }

          it { should eq 1 }
        end
      end

    end

    context "when we need to call to_s on the value" do
      let(:object) { double(:existing_method => 1) }

      subject { with_helpers.extract_value(object, :existing_method, nil, true) }

      it { should eq "1" }
    end
  end

  describe "#format_args" do
    let(:object) { Object.new }
    let(:args) do
      [
        "Model",
        1,
        object,
        "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
      ]
    end

    it "should format the arguments" do
      with_helpers.format_args(args).should eq([
        "Model",
        "1",
        object.inspect,
        "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ..."
      ])
    end
  end
end
