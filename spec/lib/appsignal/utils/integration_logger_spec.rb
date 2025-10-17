describe Appsignal::Utils::IntegrationLogger do
  let(:log_stream) { std_stream }
  let(:logs) { log_contents(log_stream) }
  let(:logger) do
    Appsignal::Utils::IntegrationLogger.new(log_stream).tap do |l|
      l.formatter = logger_formatter
    end
  end

  it "logs messages" do
    logger.debug("debug message")
    logger.info("info message")
    logger.warn("warning message")
    logger.error("error message")
    logger.error(ExampleStandardError.new("example error with message"))
    logger.info { "block error message" }

    expect(logs).to contains_log(:debug, "debug message")
    expect(logs).to contains_log(:info, "info message")
    expect(logs).to contains_log(:warn, "warning message")
    expect(logs).to contains_log(:error, "error message")
    expect(logs).to contains_log(:error, "example error with message")
    expect(logs).to contains_log(:info, "block error message")
  end

  describe "message truncation" do
    it "does not truncate short messages" do
      logger.error("Short error message")

      expect(logs).to contains_log(:error, "Short error message")
    end

    context "when calling logger.error(message)" do
      it "truncates long messages" do
        long_message = "a" * 2500
        logger.error(long_message)

        expect(logs).to contains_log(:error, "#{"a" * 2000}...")
      end
    end

    context "when calling logger.error { message }" do
      it "truncates long messages passed as a block" do
        long_message = "a" * 2500
        logger.error { long_message }

        expect(logs).to contains_log(:error, "#{"a" * 2000}...")
      end
    end

    context "when calling logger.add(severity, message)" do
      it "truncates long messages" do
        long_message = "a" * 2500
        logger.add(Logger::ERROR, long_message)

        expect(logs).to contains_log(:error, "#{"a" * 2000}...")
      end
    end

    context "when calling logger.error(progname) { message }" do
      it "truncates long messages from block" do
        long_message = "a" * 2500
        logger.error("progname") { long_message }

        expect(logs).to contains_log(:error, "#{"a" * 2000}...")
      end
    end
  end
end
