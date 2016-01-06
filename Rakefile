require 'rspec/core/rake_task'

GEMFILES = %w(
  capistrano2
  capistrano3
  no_dependencies
  padrino
  rails-3.2
  rails-4.0
  rails-4.1
  rails-4.2
  rails-5.0
  sequel
  sinatra
)

RUBY_VERSIONS = %w(
  1.9.3
  2.0.0
  2.1.8
  2.2.4
  2.3.0
)

VERSION_MANAGERS = {
  :rbenv => 'rbenv local',
  :rvm => 'rvm use'
}

task :publish do
  require 'appsignal/version'

  NAME = 'appsignal'
  VERSION_FILE = 'lib/appsignal/version.rb'
  CHANGELOG_FILE = 'CHANGELOG.md'

  raise '$EDITOR should be set' unless ENV['EDITOR']

  def build_and_push_gem
    puts '# Building gem'
    puts `gem build #{NAME}.gemspec`
    puts '# Publishing Gem'
    puts `gem push #{NAME}-#{gem_version}.gem`
  end

  def create_and_push_tag
    begin
      puts `git commit -am 'Bump to #{version} [ci skip]'`
      puts "# Creating tag #{version}"
      puts `git tag #{version}`
      puts `git push origin #{version}`
      puts `git push appsignal #{version}`
      puts `git push origin #{branch}`
      puts `git push appsignal #{branch}`
    rescue
      raise "Tag: '#{version}' already exists"
    end
  end

  def changes
    git_status_to_array(`git status -s -u`)
  end

  def gem_version
    Appsignal::VERSION
  end

  def version
    @version ||= 'v' << gem_version
  end

  def branch
    if gem_version.include?('alpha') ||
         gem_version.include?('beta') ||
         gem_version.include?('rc')
      'develop'
    else
      'master'
    end
  end

  def git_status_to_array(changes)
    changes.split("\n").each { |change| change.gsub!(/^.. /,'') }
  end

  raise "Branch should hold no uncommitted file change)" unless changes.empty?

  system("$EDITOR #{VERSION_FILE}")
  if changes.member?(VERSION_FILE)
    Appsignal.send(:remove_const, :VERSION)
    load File.expand_path(VERSION_FILE)
    system("$EDITOR #{CHANGELOG_FILE}")
    build_and_push_gem
    create_and_push_tag
  else
    raise "Actually change the version in: #{VERSION_FILE}"
  end
end

task :install do
  system 'cd ext && rm -f libappsignal.a && ruby extconf.rb && make clean && make && cd ..'
  GEMFILES.each do |gemfile|
    system "bundle --gemfile gemfiles/#{gemfile}.gemfile"
  end
end

task :spec_all_gemfiles do
  GEMFILES.each do |gemfile|
    puts "Running #{gemfile}"
    raise 'Not successful' unless system("env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec")
  end
end

task :generate_bundle_and_spec_all do
  VERSION_MANAGERS.each do |version_manager, switch_command|
    out = []
    if version_manager == 'rvm use'
      out << '#!/bin/bash --login'
    else
      out << '#!/bin/sh'
    end
    out << 'rm -f .ruby-version'
    out << "echo 'Using #{version_manager}'"
    RUBY_VERSIONS.each do |version|
      out << "echo 'Switching to #{version}'"
      out << "#{switch_command} #{version} || { echo 'Switching Ruby failed'; exit 1; }"
      out << 'cd ext && rm -f libappsignal.a && ruby extconf.rb && make clean && make && cd ..'
      GEMFILES.each do |gemfile|
        out << "echo 'Bundling #{gemfile} in #{version}'"
        out << "bundle --quiet --gemfile gemfiles/#{gemfile}.gemfile || { echo 'Bundling failed'; exit 1; }"
        out << "echo 'Running #{gemfile} in #{version}'"
        out << "env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec || { echo 'Running specs failed'; exit 1; }"
      end
    end
    out << 'rm -f .ruby-version'
    out << "echo 'Successfully ran specs for all environments'"

    script = "bundle_and_spec_all_#{version_manager}.sh"
    File.open(script, 'w') do |file|
      file.write out.join("\n")
    end
    File.chmod(0775, script)
    puts "Generated #{script}"
  end
end

task :console do
  require 'irb'
  require 'irb/completion'
  require 'appsignal'

  Appsignal.config = Appsignal::Config.new('.', :console)

  ARGV.clear
  IRB.start
end

task :install_extension do
  `cd ext && rm -f libappsignal.a && ruby extconf.rb && make clean && make`
end

RSpec::Core::RakeTask.new(:rspec) do |t|
  t.pattern = Dir.glob('spec/**/*_spec.rb')
end

task :travis => [:install_extension, :rspec]

task :default => [:generate_bundle_and_spec_all, :spec_all_gemfiles]
