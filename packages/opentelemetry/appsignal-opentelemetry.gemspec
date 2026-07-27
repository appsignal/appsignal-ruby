# frozen_string_literal: true

require_relative "lib/appsignal_opentelemetry/version"

# The OpenTelemetry gems and their minimum versions live in this
# dependency-free file in the main gem, which is the single source of truth
# for the set collector mode requires.
require_relative "../../lib/appsignal/opentelemetry/dependencies"

Gem::Specification.new do |gem|
  gem.name        = "appsignal-opentelemetry"
  gem.version     = AppsignalOpentelemetry::VERSION
  gem.authors     = [
    "Robert Beekman",
    "Thijs Cadier",
    "Tom de Bruijn"
  ]
  gem.email       = ["support@appsignal.com"]
  gem.summary     = "Installs the OpenTelemetry gems AppSignal collector mode needs"
  gem.description = "A companion gem for appsignal that pulls in the OpenTelemetry " \
    "gems required to run AppSignal in collector mode."
  gem.homepage    = "https://github.com/appsignal/appsignal-ruby"
  gem.license     = "MIT"

  # Collector mode requires Ruby 3.1 or newer, so this companion gem does too.
  # This mirrors `MIN_RUBY_VERSION_FOR_COLLECTOR_MODE` in `Appsignal::Config`,
  # which is not cheap to load from a gemspec, so the value is hardcoded here.
  gem.required_ruby_version = ">= 3.1"

  # Build the file list from a local glob rather than `git ls-files` so this
  # gem only ever packages its own directory.
  gem.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "*.gemspec", "CHANGELOG.md", "README.md"]
  end
  gem.require_paths = ["lib"]

  gem.metadata = {
    "rubygems_mfa_required" => "true",
    "changelog_uri" =>
      "https://github.com/appsignal/appsignal-ruby/blob/main/packages/opentelemetry/CHANGELOG.md",
    "source_code_uri" => "https://github.com/appsignal/appsignal-ruby"
  }

  gem.add_dependency "appsignal", "4.9.1"

  # Add the OpenTelemetry gems by looping over the shared list instead of
  # listing them here. This keeps `REQUIRED_GEMS` the single source of truth,
  # so this gem's dependencies can never drift from what the runtime requires.
  Appsignal::OpenTelemetry::REQUIRED_GEMS.each do |name, constraints|
    gem.add_dependency name, *constraints
  end
end
