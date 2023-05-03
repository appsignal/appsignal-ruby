RSpec::Matchers.define :contains_log do |level, message|
  expected_log_line = "[#{level.upcase}] #{message}"

  match do |actual|
    actual.include?(expected_log_line)
  end

  failure_message do |actual|
    <<~MESSAGE
      Did not contain log line:
      #{expected_log_line}

      Received logs:
      #{actual}
    MESSAGE
  end

  diffable
end
