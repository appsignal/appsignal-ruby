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

    expect(logs).to contains_log(:debug, "debug message")
    expect(logs).to contains_log(:info, "info message")
    expect(logs).to contains_log(:warn, "warning message")
    expect(logs).to contains_log(:error, "error message")
  end
end
