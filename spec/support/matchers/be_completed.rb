RSpec::Matchers.define :be_completed do
  match do |transaction|
    values_match? transaction.ext._completed?, true
  end
end
