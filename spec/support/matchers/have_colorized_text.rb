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
