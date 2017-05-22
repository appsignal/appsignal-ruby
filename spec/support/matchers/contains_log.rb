RSpec::Matchers.define :contains_log do |level, message|
  match do |actual|
    actual.include?("[#{level.upcase}] #{message}")
  end

  diffable
end
