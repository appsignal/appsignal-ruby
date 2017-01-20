class MockFormatter < Appsignal::EventFormatter
  register "mock"

  attr_reader :body

  def initialize
    @body = "some value"
  end

  def format(_payload)
    ["title", @body]
  end
end

class MissingFormatMockFormatter < Appsignal::EventFormatter
  def transform(payload)
  end
end

class IncorrectFormatMockFormatter < Appsignal::EventFormatter
  def format
  end
end

class MockDependentFormatter < Appsignal::EventFormatter
  register "mock.dependent"

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
      expect(klass.formatters["mock"]).to be_instance_of(MockFormatter)
    end

    it "should know wether a formatter is registered" do
      expect(klass.registered?("mock")).to be_truthy
      expect(klass.registered?("mock", MockFormatter)).to be_truthy
      expect(klass.registered?("mock", Hash)).to be_falsy
      expect(klass.registered?("nonsense")).to be_falsy
    end

    it "doesn't register formatters that raise a name error in the initializer" do
      expect(klass.registered?("mock.dependent")).to be_falsy
    end

    it "doesn't register formatters that don't have a format(payload) method" do
      klass.register("mock.missing_format", MissingFormatMockFormatter)
      klass.register("mock.incorrect_format", IncorrectFormatMockFormatter)

      Appsignal::EventFormatter.initialize_formatters

      expect(klass.registered?("mock.missing_format")).to be_falsy
      expect(klass.registered?("mock.incorrect_format")).to be_falsy
    end

    it "should register a custom formatter" do
      klass.register("mock.specific", MockFormatter)
      Appsignal::EventFormatter.initialize_formatters

      expect(klass.formatter_classes["mock.specific"]).to eq MockFormatter
      expect(klass.registered?("mock.specific")).to be_truthy
      expect(klass.formatters["mock.specific"]).to be_instance_of(MockFormatter)
      expect(klass.formatters["mock.specific"].body).to eq "some value"
    end

    it "should not have a formatter that's not registered" do
      expect(klass.formatters["nonsense"]).to be_nil
    end

    it "should unregister a formatter if the registered one has the same class" do
      klass.register("mock.unregister", MockFormatter)

      klass.unregister("mock.unregister", Hash)
      expect(klass.registered?("mock.unregister")).to be_truthy

      klass.unregister("mock.unregister", MockFormatter)
      expect(klass.registered?("mock.unregister")).to be_falsy
    end
  end

  context "calling formatters" do
    it "should return nil if there is no formatter registered" do
      expect(klass.format("nonsense", {})).to be_nil
    end

    it "should call the formatter if it is registered and use a value set in the initializer" do
      expect(klass.format("mock", {})).to eq ["title", "some value"]
    end
  end
end
