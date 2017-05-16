module LogHelpers
  def use_logger_with(log)
    Appsignal.logger = Logger.new(log)
    Appsignal.logger.formatter =
      proc do |severity, _datetime, _progname, msg|
        # This format is used in the `contains_log` matcher.
        "[#{severity}] #{msg}\n"
      end
    yield
    Appsignal.logger = nil
  end

  def log_contents(log)
    log.rewind
    log.read
  end
end
