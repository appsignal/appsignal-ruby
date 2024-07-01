describe Appsignal::Utils::IntegrationLogger do
  let(:formatter) { nil }
  let(:logger) do
    Appsignal::Utils::IntegrationMemoryLogger.new.tap do |l|
      l.formatter = formatter if formatter
    end
  end

  describe "#add" do
    it "adds a log message with the severity" do
      logger.add(:DEBUG, "debug message")
      logger.add(:INFO, "info message")
      logger.add(:WARN, "warn message")
      logger.add(:ERROR, "error message")
      logger.add(:FATAL, "fatal message")
      logger.add(:UNKNOWN, "unknown message")

      expect(logger.messages[:DEBUG]).to eq(["debug message"])
      expect(logger.messages[:INFO]).to eq(["info message"])
      expect(logger.messages[:WARN]).to eq(["warn message"])
      expect(logger.messages[:ERROR]).to eq(["error message"])
      expect(logger.messages[:FATAL]).to eq(["fatal message"])
      expect(logger.messages[:UNKNOWN]).to eq(["unknown message"])
    end

    context "without formatter" do
      it "logs in the default format" do
        logger.add(:DEBUG, "debug message")
        expect(logger.messages[:DEBUG]).to eq(["debug message"])
      end
    end

    context "with formatter" do
      let(:formatter) do
        proc do |severity, _datetime, _progname, msg|
          "[TIME (process) #PID][#{severity}] #{msg}\n"
        end
      end

      it "formats the logs using the formatter" do
        logger.add(:DEBUG, "debug message")
        expect(logger.messages[:DEBUG]).to eq(["[TIME (process) #PID][DEBUG] debug message\n"])
      end
    end
  end

  describe "#debug" do
    it "adds a log message with the debug severity" do
      logger.debug("debug message")

      expect(logger.messages[:DEBUG]).to eq(["debug message"])
    end
  end

  describe "#info" do
    it "adds a log message with the info severity" do
      logger.info("info message")

      expect(logger.messages[:INFO]).to eq(["info message"])
    end
  end

  describe "#warn" do
    it "adds a log message with the warn severity" do
      logger.warn("warn message")

      expect(logger.messages[:WARN]).to eq(["warn message"])
    end
  end

  describe "#warn_once_then_debug" do
    it "only warns once, then uses debug" do
      message = "This is a log line"
      3.times { logger.warn_once_then_debug(:key, message) }

      expect(logger.messages[:WARN]).to eq([message])
      expect(logger.messages[:DEBUG]).to eq([message, message])
    end
  end

  describe "#error" do
    it "adds a log message with the error severity" do
      logger.error("error message")

      expect(logger.messages[:ERROR]).to eq(["error message"])
    end
  end

  describe "#fatal" do
    it "adds a log message with the fatal severity" do
      logger.fatal("fatal message")

      expect(logger.messages[:FATAL]).to eq(["fatal message"])
    end
  end

  describe "#unknown" do
    it "adds a log message with the unknown severity" do
      logger.unknown("unknown message")

      expect(logger.messages[:UNKNOWN]).to eq(["unknown message"])
    end
  end

  describe "#clear" do
    it "clears all log messages" do
      logger.add(:DEBUG, "debug message")
      logger.add(:INFO, "info message")
      logger.add(:WARN, "warn message")
      logger.add(:ERROR, "error message")
      logger.add(:FATAL, "fatal message")
      logger.add(:UNKNOWN, "unknown message")
      logger.clear

      expect(logger.messages).to be_empty
    end
  end

  describe "#messages_for_level" do
    it "returns only log messages for level and higher" do
      logger.add(:DEBUG, "debug message")
      logger.add(:INFO, "info message")
      logger.add(:WARN, "warn message")
      logger.add(:ERROR, "error message")
      logger.add(:FATAL, "fatal message")
      logger.add(:UNKNOWN, "unknown message")

      expect(logger.messages_for_level(Logger::DEBUG)).to eq([
        "debug message",
        "info message",
        "warn message",
        "error message",
        "fatal message",
        "unknown message"
      ])
      expect(logger.messages_for_level(Logger::INFO)).to eq([
        "info message",
        "warn message",
        "error message",
        "fatal message",
        "unknown message"
      ])
      expect(logger.messages_for_level(Logger::WARN)).to eq([
        "warn message",
        "error message",
        "fatal message",
        "unknown message"
      ])
      expect(logger.messages_for_level(Logger::ERROR)).to eq([
        "error message",
        "fatal message",
        "unknown message"
      ])
      expect(logger.messages_for_level(Logger::FATAL)).to eq([
        "fatal message",
        "unknown message"
      ])
      expect(logger.messages_for_level(Logger::UNKNOWN)).to eq([
        "unknown message"
      ])
    end
  end
end
