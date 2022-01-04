require File.expand_path("../lib/appsignal/version", __FILE__)

Gem::Specification.new do |gem| # rubocop:disable Metrics/BlockLength
  gem.authors = [
    "Robert Beekman",
    "Thijs Cadier",
    "Tom de Bruijn"
  ]
  gem.email                 = ["support@appsignal.com"]
  gem.description           = "The official appsignal.com gem"
  gem.summary               = "Logs performance and exception data from your app to "\
                              "appsignal.com"
  gem.homepage              = "https://github.com/appsignal/appsignal-ruby"
  gem.license               = "MIT"

  gem.files                 = `git ls-files`.split($\).reject { |f| f.start_with?(".changesets/") } # rubocop:disable Style/SpecialGlobalVars
  gem.executables           = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files            = gem.files.grep(%r{^(test|spec|features)/})
  gem.name                  = "appsignal"
  gem.require_paths         = %w[lib ext]
  gem.version               = Appsignal::VERSION
  gem.required_ruby_version = ">= 2.0"
  # Default extension installer. Overridden by JRuby gemspec as defined in
  # `Rakefile`.
  gem.extensions            = %w[ext/extconf.rb]

  gem.metadata = {
    "bug_tracker_uri"   => "https://github.com/appsignal/appsignal-ruby/issues",
    "changelog_uri"     =>
      "https://github.com/appsignal/appsignal-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://docs.appsignal.com/ruby/",
    "homepage_uri"      => "https://docs.appsignal.com/ruby/",
    "source_code_uri"   => "https://github.com/appsignal/appsignal-ruby"
  }

  gem.add_dependency "rack"

  gem.add_development_dependency "rake", "~> 11"
  gem.add_development_dependency "rspec", "~> 3.8"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "yard", ">= 0.9.20"
  gem.add_development_dependency "pry"

  # Dependencies that need to be locked to a specific version in developement
  ruby_version = Gem::Version.new(RUBY_VERSION)
  if ruby_version > Gem::Version.new("2.5.0")
    # RuboCop dependency parallel depends on Ruby > 2.4
    gem.add_development_dependency "rubocop", "0.50.0"
  end
  if ruby_version < Gem::Version.new("2.1.0")
    # Newer versions of rexml use keyword arguments with optional arguments which
    # work in Ruby 2.1 and newer.
    gem.add_development_dependency "rexml", "3.2.4"
  end
  if ruby_version < Gem::Version.new("2.1.0")
    # public_suffix 3.0 and newer don't support Ruby < 2.1
    gem.add_development_dependency "public_suffix", "~> 2.0.5"
  elsif ruby_version < Gem::Version.new("2.3.0")
    # public_suffix 4.0 and newer don't support Ruby < 2.3
    gem.add_development_dependency "public_suffix", "~> 3.1.1"
  end
end
