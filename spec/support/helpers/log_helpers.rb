module LogHelpers
  def capture_logs(&block)
    log = std_stream
    use_logger_with(log, &block)
    log_contents(log)
  end

  def use_logger_with(log)
    Appsignal.internal_logger = test_logger(log)
    yield
    Appsignal.internal_logger = nil
  end

  def test_logger(log)
    Appsignal::Utils::IntegrationLogger.new(log).tap do |logger|
      logger.formatter = logger_formatter
    end
  end

  def logger_formatter
    proc do |severity, _datetime, _progname, msg|
      log_line(severity, msg)
    end
  end

  def log_line(severity, message)
    # This format is used in the `contains_log` matcher.
    "[#{severity}] #{message}\n"
  end

  def log_contents(log)
    log.rewind
    log.read
  end
end
