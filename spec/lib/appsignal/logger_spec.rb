describe Appsignal::Logger do
  let(:logger) { Appsignal::Logger.new(STDOUT) }

  describe "#seen_keys" do
    it "returns a Set" do
      expect(logger.seen_keys).to be_a(Set)
    end
  end

  describe "#warn_once_then_debug" do
    it "only warns once, then uses debug" do
      expect(logger).to receive(:warn).once.with("This is a log line")
      expect(logger).to receive(:debug).twice.with("This is a log line")

      3.times { logger.warn_once_then_debug(:key, "This is a log line") }

      expect(logger).to receive(:warn).once.with("This is anoter log line")
      logger.warn_once_then_debug(:other_key, "This is anoter log line")
    end
  end
end
