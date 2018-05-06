class MockFormatter < Appsignal::EventFormatter
  attr_reader :body

  def initialize
    @body = "some value"
  end

  def format(_payload)
    ["title", body]
  end
end

class MissingFormatMockFormatter < Appsignal::EventFormatter
  def transform(_payload)
  end
end

class IncorrectFormatMockFormatter < Appsignal::EventFormatter
  def format
  end
end

class MockDependentFormatter < Appsignal::EventFormatter
  def initialize
    NonsenseDependency.something
  end
end

Appsignal::EventFormatter.register "mock", MockFormatter
Appsignal::EventFormatter.register "mock.dependent", MockDependentFormatter

describe Appsignal::EventFormatter do
  before do
    klass.register("mock", MockFormatter)
  end

  let(:klass) { Appsignal::EventFormatter }

  let(:deprecated_formatter) do
    Class.new(Appsignal::EventFormatter) do
      register "mock.deprecated"

      def format(_payload)
      end
    end
  end

  context "registering and unregistering formatters" do
    it "registers a formatter" do
      expect(klass.formatters["mock"]).to be_instance_of(MockFormatter)
    end

    it "knows whether a formatter is registered" do
      expect(klass.registered?("mock")).to be_truthy
      expect(klass.registered?("mock", MockFormatter)).to be_truthy
      expect(klass.registered?("mock", Hash)).to be_falsy
      expect(klass.registered?("nonsense")).to be_falsy
    end

    it "doesn't register formatters that raise a name error in the initializer" do
      expect(klass.registered?("mock.dependent")).to be_falsy
    end

    it "registers a custom formatter" do
      klass.register("mock.specific", MockFormatter)

      expect(klass.formatter_classes["mock.specific"]).to eq MockFormatter
      expect(klass.registered?("mock.specific")).to be_truthy
      expect(klass.formatters["mock.specific"]).to be_instance_of(MockFormatter)
      expect(klass.formatters["mock.specific"].body).to eq "some value"
    end

    it "does not know a formatter that's not registered" do
      expect(klass.formatters["nonsense"]).to be_nil
    end

    it "unregistering a formatter if the registered one has the same class" do
      klass.register("mock.unregister", MockFormatter)

      klass.unregister("mock.unregister", Hash)
      expect(klass.registered?("mock.unregister")).to be_truthy

      klass.unregister("mock.unregister", MockFormatter)
      expect(klass.registered?("mock.unregister")).to be_falsy
    end

    it "does not register two formatters for the same name" do
      expect(Appsignal.logger).to receive(:warn)
        .with("Formatter for 'mock.twice' already registered, not registering 'MockFormatter'")
      klass.register("mock.twice", MockFormatter)
      klass.register("mock.twice", MockFormatter)
    end

    it "does not register deprecated formatters" do
      expect(Appsignal.logger).to receive(:warn)
        .with("Formatter for 'mock.deprecated' is using a deprecated registration method. " \
              "This event formatter will not be loaded. " \
              "Please update the formatter according to the documentation at: " \
              "https://docs.appsignal.com/ruby/instrumentation/event-formatters.html")

      deprecated_formatter

      expect(Appsignal::EventFormatter.deprecated_formatter_classes.keys).to include("mock.deprecated")
    end

    it "initializes deprecated formatters" do
      deprecated_formatter
      Appsignal::EventFormatter.initialize_deprecated_formatters

      expect(klass.registered?("mock.deprecated")).to be_truthy
    end
  end

  context "calling formatters" do
    it "returns nil if there is no formatter registered" do
      expect(klass.format("nonsense", {})).to be_nil
    end

    it "calls the formatter if it is registered and use a value set in the initializer" do
      expect(klass.format("mock", {})).to eq ["title", "some value"]
    end
  end
end
