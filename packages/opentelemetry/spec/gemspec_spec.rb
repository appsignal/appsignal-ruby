# frozen_string_literal: true

require_relative "../../../lib/appsignal/opentelemetry/dependencies"

RSpec.describe "appsignal-opentelemetry.gemspec" do
  let(:gemspec_path) do
    File.expand_path("../appsignal-opentelemetry.gemspec", __dir__)
  end
  let(:gemspec) { Gem::Specification.load(gemspec_path) }

  it "loads as a valid gemspec named appsignal-opentelemetry" do
    expect(gemspec).to be_a(Gem::Specification)
    expect(gemspec.name).to eq("appsignal-opentelemetry")
    expect { gemspec.validate }.to_not raise_error
  end

  it "requires Ruby 3.1 or newer" do
    expect(gemspec.required_ruby_version.to_s).to eq(">= 3.1")
  end

  it "depends on appsignal plus every required OpenTelemetry gem at its floor" do
    expected = { "appsignal" => "= #{gemspec.version}" }
    Appsignal::OpenTelemetry::REQUIRED_GEMS.each do |name, minimum_version|
      expected[name] = ">= #{minimum_version}"
    end

    actual = gemspec.dependencies.to_h do |dependency|
      [dependency.name, dependency.requirement.to_s]
    end

    expect(actual).to eq(expected)
  end
end
