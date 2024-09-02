RSpec::Matchers.define :contains_log do |level, message|
  log_level_prefix = level.upcase

  match do |actual|
    case message
    when Regexp
      /\[#{log_level_prefix}\] #{message}/.match?(actual)
    else
      expected_log_line = "[#{log_level_prefix}] #{message}"
      actual.include?(expected_log_line)
    end
  end

  failure_message do |actual|
    <<~MESSAGE
      Did not contain log line:
      Log level: #{log_level_prefix}
      Message: #{message}

      Received logs:
      #{actual}
    MESSAGE
  end

  diffable
end
