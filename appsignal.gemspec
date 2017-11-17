# -*- encoding: utf-8 -*-

require File.expand_path("../lib/appsignal/version", __FILE__)

Gem::Specification.new do |gem|
  gem.authors = [
    "Robert Beekman",
    "Thijs Cadier"
  ]
  gem.email                 = ["support@appsignal.com"]
  gem.description           = "The official appsignal.com gem"
  gem.summary               = "Logs performance and exception data from your app to "\
                              "appsignal.com"
  gem.homepage              = "https://github.com/appsignal/appsignal"
  gem.license               = "MIT"

  gem.files                 = `git ls-files`.split($\) # rubocop:disable Style/SpecialGlobalVars
  gem.executables           = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files            = gem.files.grep(%r{^(test|spec|features)/})
  gem.name                  = "appsignal"
  gem.require_paths         = %w[lib ext]
  gem.version               = Appsignal::VERSION
  gem.required_ruby_version = ">= 1.9"

  gem.extensions = %w[ext/extconf.rb]

  gem.add_dependency "rack"

  gem.add_development_dependency "rake", "~> 11"
  gem.add_development_dependency "rspec", "~> 3.6"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "webmock"
  gem.add_development_dependency "rubocop", "0.49.0"
  gem.add_development_dependency "yard"
end
