class MockFormatter < Appsignal::EventFormatter
  attr_reader :body

  def initialize
    super
    @body = "some value"
  end

  def format(_payload)
    ["title", body]
  end
end

class MockFormatterDouble < MockFormatter
end

class MissingFormatMockFormatter
end

class UntitledMockFormatter < Appsignal::EventFormatter
end

class ClientMockFormatter < Appsignal::EventFormatter
  def opentelemetry_kind
    :client
  end
end

class DescribedMockFormatter < Appsignal::EventFormatter
  def opentelemetry_attributes(payload)
    { "mock.attribute" => payload[:value] }
  end
end

class IncorrectFormatMockFormatter < Appsignal::EventFormatter
  def format
  end
end

class IncorrectFormatMock2Formatter < Appsignal::EventFormatter
  def format(_payload, _foo = nil)
  end
end

class MockDependentFormatter < Appsignal::EventFormatter
  def initialize
    super
    raise "There is an error"
  end

  def format(_payload)
  end
end

describe Appsignal::EventFormatter do
  let(:klass) { described_class }

  # Registering an event formatter writes to a registry that is shared by the
  # whole test suite, so this file has to leave it as it found it.
  before(:context) do
    @formatters = Appsignal::EventFormatter.formatters.dup
    @formatter_classes = Appsignal::EventFormatter.formatter_classes.dup
  end

  after(:context) do
    expect(Appsignal::EventFormatter.formatters).to eq(@formatters)
    expect(Appsignal::EventFormatter.formatter_classes).to eq(@formatter_classes)
  end

  around do |example|
    formatters = described_class.formatters.dup
    formatter_classes = described_class.formatter_classes.dup
    example.run
  ensure
    described_class.formatters.replace(formatters)
    described_class.formatter_classes.replace(formatter_classes)
  end

  describe "the event formatters in this gem" do
    it "inherit from Appsignal::EventFormatter" do
      expect(klass.formatter_classes.values.uniq).to all(be < described_class)
    end
  end

  describe ".register" do
    it "registers a formatter" do
      expect(klass.registered?("mock")).to be_falsy

      klass.register "mock", MockFormatter

      expect(klass.formatters["mock"]).to be_instance_of(MockFormatter)
      expect(klass.formatter_classes["mock"]).to eq MockFormatter
    end

    context "when a formatter with the name already exists" do
      it "does not register the formatter again" do
        logs = capture_logs do
          klass.register("mock.twice", MockFormatter)
          klass.register("mock.twice", MockFormatter)
        end
        expect(klass.registered?("mock.twice")).to be_truthy
        expect(logs).to contains_log :warn,
          "Formatter for 'mock.twice' already registered, not registering 'MockFormatter'"
      end
    end

    context "when the formatter registers itself" do
      it "registers it where the other formatters are registered" do
        MockFormatter.register("mock.self_register", MockFormatter)

        expect(klass.registered?("mock.self_register")).to be_truthy
        expect(klass.format("mock.self_register", {})).to eq ["title", "some value"]
      end
    end

    context "when the formatter does not implement format" do
      it "registers the formatter, which gives the event no title or body" do
        klass.register("mock.untitled", UntitledMockFormatter)

        expect(klass.registered?("mock.untitled")).to be_truthy
        expect(klass.format("mock.untitled", {})).to be_nil
      end
    end

    context "when there is an error initializing the formatter" do
      it "does not register the formatter and logs an error" do
        logs = capture_logs do
          described_class.register "mock.dependent", MockDependentFormatter
        end
        expect(klass.registered?("mock.dependent")).to be_falsy
        expect(logs).to contains_log :error,
          "'There is an error' " \
            "when initializing mock.dependent event formatter"
      end
    end

    context "when formatter has no format/1 method" do
      context "when the formatter has no format method" do
        it "does not register the formatter and logs an error" do
          logs = capture_logs do
            described_class.register "mock.missing", MissingFormatMockFormatter
          end
          expect(klass.registered?("mock.missing")).to be_falsy
          expect(logs).to contains_log :error,
            "'MissingFormatMockFormatter does not have a format(payload) " \
              "method' when initializing mock.missing event formatter"
        end
      end

      context "when the formatter has an format/0 method" do
        it "does not register the formatter and logs an error" do
          logs = capture_logs do
            described_class.register "mock.incorrect", IncorrectFormatMockFormatter
          end
          expect(klass.registered?("mock.incorrect")).to be_falsy
          expect(logs).to contains_log :error,
            "'IncorrectFormatMockFormatter does not have a format(payload) " \
              "method' when initializing mock.incorrect event formatter"
        end
      end

      context "when formatter has an format/2 method" do
        it "does not register the formatter and logs an error" do
          logs = capture_logs do
            described_class.register "mock.incorrect", IncorrectFormatMock2Formatter
          end
          expect(klass.registered?("mock.incorrect")).to be_falsy
          expect(logs).to contains_log :error,
            "'IncorrectFormatMock2Formatter does not have a format(payload) " \
              "method' when initializing mock.incorrect event formatter"
        end
      end
    end
  end

  describe ".registered?" do
    context "when checking by name" do
      context "when there is a formatter with that name" do
        it "returns true" do
          klass.register "mock", MockFormatter
          expect(klass.registered?("mock")).to be_truthy
        end
      end

      context "when there is no formatter with that name" do
        it "returns false" do
          expect(klass.registered?("nonsense")).to be_falsy
        end
      end
    end

    context "when checking by name and class" do
      context "when there is a formatter with that name and class" do
        it "returns true" do
          klass.register "mock", MockFormatter
          expect(klass.registered?("mock", MockFormatter)).to be_truthy
        end
      end

      context "when there is no formatter with that name and class" do
        it "returns false" do
          klass.register "mock", MockFormatterDouble
          expect(klass.registered?("mock", MockFormatter)).to be_falsy
        end
      end
    end
  end

  describe ".unregister" do
    context "when a formatter with the name is registered" do
      it "unregisters the formatter has the same class" do
        klass.register("mock.unregister", MockFormatter)
        expect(klass.registered?("mock.unregister")).to be_truthy

        klass.unregister("mock.unregister", Hash)
        expect(klass.registered?("mock.unregister")).to be_truthy

        klass.unregister("mock.unregister", MockFormatter)
        expect(klass.registered?("mock.unregister")).to be_falsy
      end
    end

    context "when the formatter unregisters itself" do
      it "unregisters the formatter" do
        klass.register("mock.self_unregister", MockFormatter)
        expect(klass.registered?("mock.self_unregister")).to be_truthy

        MockFormatter.unregister("mock.self_unregister")

        expect(klass.registered?("mock.self_unregister")).to be_falsy
      end
    end

    context "when a formatter with the same name and class is not registered" do
      it "unregisters nothing" do
        expect do
          expect do
            klass.unregister("nonse.unregister", MockFormatter)
          end.to_not(change { klass.formatters })
        end.to_not(change { klass.formatter_classes })
      end
    end
  end

  describe ".opentelemetry_kind" do
    context "when the formatter declares a kind" do
      it "returns it" do
        klass.register("mock.client", ClientMockFormatter)
        expect(klass.opentelemetry_kind("mock.client")).to eq(:client)
      end
    end

    context "when the formatter declares no kind" do
      it "returns nil" do
        klass.register("mock", MockFormatter)
        expect(klass.opentelemetry_kind("mock")).to be_nil
      end
    end

    # An event can be instrumented under a Symbol name, while every formatter
    # is registered under a String one.
    context "when the event name is a Symbol" do
      it "returns the kind the formatter registered under the String declares" do
        klass.register("mock.symbol_kind", ClientMockFormatter)

        expect(klass.opentelemetry_kind(:"mock.symbol_kind")).to eq(:client)
      end
    end

    context "when no formatter with the name is registered" do
      it "returns nil" do
        expect(klass.opentelemetry_kind("nonsense")).to be_nil
      end
    end
  end

  describe ".opentelemetry_attributes" do
    context "when the formatter describes the event" do
      it "returns the attributes it reads from the payload" do
        klass.register("mock.described", DescribedMockFormatter)
        expect(klass.opentelemetry_attributes("mock.described", :value => "read"))
          .to eq("mock.attribute" => "read")
      end
    end

    context "when the formatter describes nothing" do
      it "returns nil" do
        klass.register("mock", MockFormatter)
        expect(klass.opentelemetry_attributes("mock", {})).to be_nil
      end
    end

    context "when the event name is a Symbol" do
      it "returns what the formatter registered under the String describes" do
        klass.register("mock.symbol_described", DescribedMockFormatter)

        expect(klass.opentelemetry_attributes(:"mock.symbol_described", :value => "read"))
          .to eq("mock.attribute" => "read")
      end
    end

    context "when no formatter with the name is registered" do
      it "returns nil" do
        expect(klass.opentelemetry_attributes("nonsense", {})).to be_nil
      end
    end
  end

  describe ".format" do
    context "when no formatter with the name is registered" do
      it "returns nil" do
        expect(klass.format("nonsense", {})).to be_nil
      end
    end

    context "when a formatter with the name is registered" do
      it "calls the formatter and use a value set in the initializer" do
        klass.register "mock", MockFormatter
        expect(klass.format("mock", {})).to eq ["title", "some value"]
      end
    end
  end
end
