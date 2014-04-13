# -*- encoding: utf-8 -*-
require File.expand_path('../lib/appsignal/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = [
    'Robert Beekman',
    'Steven Weller',
    'Thijs Cadier',
    'Ron Cadier',
    'Jacob Vosmaer'
  ]
  gem.email                 = ['support@appsignal.com']
  gem.description           = 'The official appsignal.com gem'
  gem.summary               = 'Logs performance and exception data from your app to'\
                              'appsignal.com'
  gem.homepage              = 'https://github.com/appsignal/appsignal'
  gem.license               = 'MIT'

  gem.files                 = `git ls-files`.split($\)
  gem.executables           = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files            = gem.files.grep(%r{^(test|spec|features)/})
  gem.name                  = 'appsignal'
  gem.require_paths         = ['lib']
  gem.version               = Appsignal::VERSION
  gem.required_ruby_version = '>= 1.9.3'

  gem.add_dependency 'activesupport', '>= 3.0'
  gem.add_dependency 'rack'
  gem.add_dependency 'thread_safe'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'timecop'

  if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    gem.add_development_dependency 'racc'
    gem.add_development_dependency 'rubysl-enumerator'
    gem.add_development_dependency 'rubysl-net-http'
    gem.add_development_dependency 'rubysl-rexml'
    gem.add_development_dependency 'rubysl-test-unit'
  end
end
