RSpec::Matchers.define :have_colorized_text do |color, text|
  match do |actual|
    color_codes = Appsignal::CLI::Helpers::COLOR_CODES
    reset_color_code = color_codes.fetch(:default)
    color_code = color_codes.fetch(color)

    @expected = "\e[#{color_code}m#{text}\e[#{reset_color_code}m"
    expect(actual).to include(@expected)
  end

  diffable
  attr_reader :expected
end

COLOR_TAG_MATCHER_REGEX = /\e\[(\d+)m/.freeze
RSpec::Matchers.define :have_color_markers do
  match do |actual|
    actual =~ COLOR_TAG_MATCHER_REGEX
  end

  failure_message do
    "expected that output contains color markers: /\\e[\\d+m/"
  end

  failure_message_when_negated do
    "expected that output does not contain color markers: /\\e[\\d+m/"
  end
end
