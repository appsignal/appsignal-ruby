module LogHelpers
  def use_logger_with(log)
    Appsignal.logger = test_logger(log)
    yield
    Appsignal.logger = nil
  end

  def test_logger(log)
    Logger.new(log).tap do |logger|
      logger.formatter =
        proc do |severity, _datetime, _progname, msg|
          # This format is used in the `contains_log` matcher.
          "[#{severity}] #{msg}\n"
        end
    end
  end

  def log_contents(log)
    log.rewind
    log.read
  end
end
