# frozen_string_literal: true

require "opentelemetry/sdk"
require "opentelemetry-logs-sdk"

describe Appsignal::Logger::OpenTelemetryBackend do
  let(:exporter) { ::OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new }
  let(:logger_provider) do
    provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new
    provider.add_log_record_processor(
      ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter)
    )
    provider
  end

  before do
    ::OpenTelemetry.logger_provider = logger_provider
    described_class.reset!
  end

  after { described_class.reset! }

  def emitted_records
    exporter.emitted_log_records
  end

  describe ".emit" do
    it "emits a log record carrying the formatted body and severity" do
      described_class.emit("my-group", ::Logger::INFO, Appsignal::Logger::JSON, "hello world", {})

      record = emitted_records.first
      expect(record.body).to eq("hello world")
      expect(record.severity_number).to eq(9)
      expect(record.severity_text).to eq("INFO")
    end

    it "attaches appsignal.group and appsignal.format on every record" do
      described_class.emit(
        "my-group",
        ::Logger::WARN,
        Appsignal::Logger::LOGFMT,
        "msg",
        {}
      )

      attrs = emitted_records.first.attributes
      expect(attrs["appsignal.group"]).to eq("my-group")
      expect(attrs["appsignal.format"]).to eq("logfmt")
    end

    it "maps every supported format flag to its lowercase name" do
      {
        Appsignal::Logger::PLAINTEXT => "plaintext",
        Appsignal::Logger::LOGFMT => "logfmt",
        Appsignal::Logger::JSON => "json",
        Appsignal::Logger::AUTODETECT => "autodetect"
      }.each do |flag, name|
        described_class.emit("g", ::Logger::INFO, flag, "m", {})
        expect(emitted_records.last.attributes["appsignal.format"]).to eq(name)
      end
    end

    it "carries user attributes through with coerced keys and values" do
      described_class.emit(
        "g",
        ::Logger::INFO,
        Appsignal::Logger::AUTODETECT,
        "msg",
        {
          :string => "value",
          "symbol" => :sym,
          :integer => 42,
          :float => 1.5,
          :truthy => true,
          :falsy => false,
          :other => Time.utc(2026, 1, 2, 3, 4, 5)
        }
      )

      attrs = emitted_records.first.attributes
      expect(attrs).to include(
        "string" => "value",
        "symbol" => "sym",
        "integer" => 42,
        "float" => 1.5,
        "truthy" => true,
        "falsy" => false,
        "other" => "2026-01-02 03:04:05 UTC"
      )
    end

    it "does not let user attributes override the appsignal.* keys" do
      described_class.emit(
        "the-group",
        ::Logger::INFO,
        Appsignal::Logger::JSON,
        "msg",
        { "appsignal.group" => "spoofed", "appsignal.format" => "spoofed" }
      )

      attrs = emitted_records.first.attributes
      expect(attrs["appsignal.group"]).to eq("the-group")
      expect(attrs["appsignal.format"]).to eq("json")
    end

    it "maps every Ruby Logger severity to the right OTel SeverityNumber" do
      expected = {
        ::Logger::DEBUG => [5, "DEBUG"],
        ::Logger::INFO => [9, "INFO"],
        ::Logger::WARN => [13, "WARN"],
        ::Logger::ERROR => [17, "ERROR"],
        ::Logger::FATAL => [21, "FATAL"]
      }
      expected.each do |severity, (number, text)|
        described_class.emit("g", severity, Appsignal::Logger::PLAINTEXT, "m", {})
        record = emitted_records.last
        expect(record.severity_number).to eq(number)
        expect(record.severity_text).to eq(text)
      end
    end

    it "uses the 'appsignal-logger' instrumentation scope name" do
      described_class.emit("g", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "msg", {})

      expect(emitted_records.first.instrumentation_scope.name).to eq("appsignal-logger")
    end
  end

  describe "logger caching" do
    it "fetches the OTel logger once and reuses it across emits" do
      expect(::OpenTelemetry.logger_provider).to receive(:logger)
        .with(:name => "appsignal-logger").once.and_call_original

      described_class.emit("g", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "a", {})
      described_class.emit("g", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "b", {})
    end

    it "rebuilds the logger after reset! to pick up a new provider" do
      described_class.emit("g", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "a", {})
      described_class.reset!

      new_provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new
      new_exporter = ::OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
      new_provider.add_log_record_processor(
        ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(new_exporter)
      )
      ::OpenTelemetry.logger_provider = new_provider

      described_class.emit("g", ::Logger::INFO, Appsignal::Logger::PLAINTEXT, "b", {})
      expect(new_exporter.emitted_log_records.map(&:body)).to eq(["b"])
    end
  end
end
