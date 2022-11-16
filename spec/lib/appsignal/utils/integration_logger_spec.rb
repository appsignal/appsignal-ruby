describe Appsignal::Utils::IntegrationLogger do
  let(:log) { std_stream }
  let(:logger) do
    Appsignal::Utils::IntegrationLogger.new(log).tap do |l|
      l.formatter = logger_formatter
    end
  end

  describe "#seen_keys" do
    it "returns a Set" do
      expect(logger.seen_keys).to be_a(Set)
    end
  end

  describe "#warn_once_then_debug" do
    it "only warns once, then uses debug" do
      message = "This is a log line"
      3.times { logger.warn_once_then_debug(:key, message) }

      logs = log_contents(log)
      expect(logs.scan(/#{Regexp.escape(log_line(:WARN, message))}/).count).to eql(1)
      expect(logs.scan(/#{Regexp.escape(log_line(:DEBUG, message))}/).count).to eql(2)
    end
  end
end
