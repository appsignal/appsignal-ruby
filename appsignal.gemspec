# frozen_string_literal: true

require File.expand_path("lib/appsignal/version", __dir__)

IGNORED_PATHS = [
  # Directories
  ".changesets/",
  ".github/",
  "gemfiles/",
  "script/",
  "spec/",

  # Files
  ".gitignore",
  ".gitmodules",
  ".rspec",
  ".yardopts",
  "benchmark.rake",
  "mono.yml",
  ".rubocop.yml",
  ".rubocop_todo.yml"
].freeze

Gem::Specification.new do |gem| # rubocop:disable Metrics/BlockLength
  gem.authors = [
    "Robert Beekman",
    "Thijs Cadier",
    "Tom de Bruijn"
  ]
  gem.email                 = ["support@appsignal.com"]
  gem.description           = "The official appsignal.com gem"
  gem.summary               = "Logs performance and exception data from your app to " \
    "appsignal.com"
  gem.homepage              = "https://github.com/appsignal/appsignal-ruby"
  gem.license               = "MIT"

  gem.files                 = `git ls-files`
    .split($\) # rubocop:disable Style/SpecialGlobalVars
    .reject { |f| IGNORED_PATHS.any? { |ignored_path| f.start_with?(ignored_path) } }
  gem.executables           = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name                  = "appsignal"
  gem.require_paths         = %w[lib ext]
  gem.version               = Appsignal::VERSION
  gem.required_ruby_version = ">= 2.7"
  # Default extension installer. Overridden by JRuby gemspec as defined in
  # `Rakefile`.
  gem.extensions            = %w[ext/extconf.rb]

  gem.metadata = {
    "rubygems_mfa_required" => "true",
    "bug_tracker_uri" => "https://github.com/appsignal/appsignal-ruby/issues",
    "changelog_uri" =>
      "https://github.com/appsignal/appsignal-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://docs.appsignal.com/ruby/",
    "homepage_uri" => "https://docs.appsignal.com/ruby/",
    "source_code_uri" => "https://github.com/appsignal/appsignal-ruby"
  }

  gem.add_dependency "logger"
  # Needs 2.0+ because we rely on Rack::Events
  gem.add_dependency "rack", ">= 2.0.0"

  gem.add_development_dependency "pry"
  gem.add_development_dependency "rake", ">= 12"
  gem.add_development_dependency "rspec", "~> 3.8"
  gem.add_development_dependency "rubocop", "1.64.1"
  gem.add_development_dependency("sord") unless RUBY_PLATFORM == "java"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "yard", ">= 0.9.20"
end
