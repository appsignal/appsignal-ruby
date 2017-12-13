require "bundler"
require "rubygems/package_task"
require "fileutils"

GEMFILES = %w[
  capistrano2
  capistrano3
  grape
  no_dependencies
  padrino
  rails-3.2
  rails-4.0
  rails-4.1
  rails-4.2
  rails-5.0
  resque
  sequel
  sequel-435
  sinatra
  grape
  webmachine
  que
].freeze

RUBY_VERSIONS = %w[
  2.0.0-p648
  2.1.8
  2.2.4
  2.3.0
  2.4.0
].freeze

EXCLUSIONS = {
  "rails-5.0" => %w[2.0.0 2.1.8]
}.freeze

VERSION_MANAGERS = {
  :rbenv => ->(version) { "rbenv local #{version}" },
  :rvm => ->(version) { "rvm use --default #{version.split("-").first}" }
}.freeze

namespace :build do
  def modify_base_gemspec
    eval(File.read("appsignal.gemspec")).tap do |s| # rubocop:disable Security/Eval
      yield s
    end
  end

  namespace :ruby do
    spec = modify_base_gemspec do |s|
      s.extensions = %w[ext/extconf.rb]
    end

    Gem::PackageTask.new(spec) { |_pkg| }
  end

  namespace :jruby do
    spec = modify_base_gemspec do |s|
      s.platform = "java"
      s.extensions = %w[ext/Rakefile]
      s.add_dependency "ffi"
    end

    Gem::PackageTask.new(spec) { |_pkg| }
  end

  desc "Build all gem versions"
  task :all => ["ruby:gem", "jruby:gem"]

  desc "Clean up all gem build artifacts"
  task :clean do
    FileUtils.rm_rf File.expand_path("../pkg", __FILE__)
  end
end

namespace :publish do
  VERSION_FILE = "lib/appsignal/version.rb".freeze
  CHANGELOG_FILE = "CHANGELOG.md".freeze

  def changes
    git_status_to_array(`git status -s -u`)
  end

  def git_status_to_array(changes)
    changes.split("\n").each { |change| change.gsub!(/^.. /, "") }
  end

  def current_branch
    `git rev-parse --abbrev-ref HEAD`.chomp
  end

  task :check_requirements do
    unless changes.empty?
      puts "ERROR: There should be no uncommitted file changes."
      exit 1
    end
    unless ENV["EDITOR"]
      puts "ERROR: $EDITOR environment variable should be set."
      exit 1
    end
  end

  task :configure_version do
    puts "\n# Configuring new gem version"

    puts `$EDITOR #{VERSION_FILE}`
    unless changes.member?(VERSION_FILE)
      puts "ERROR: Please actually change the gem version in: #{VERSION_FILE}"
      exit 1
    end

    puts "\n# Updating the changelog"
    puts `$EDITOR #{CHANGELOG_FILE}`
  end

  task :push_gem_packages do
    puts "\n# Pushing gem packages"
    Dir.chdir("#{File.dirname(__FILE__)}/pkg") do
      Dir["*.gem"].each do |gem_package|
        puts "## Publishing gem package: #{gem_package}"
        puts `gem push #{gem_package}`
      end
    end
  end

  task :tag_and_push_version do
    # Make sure to load the new version number
    Appsignal.send(:remove_const, :VERSION)
    load File.expand_path(VERSION_FILE)
    version = "v#{Appsignal::VERSION}"

    begin
      puts `git commit -am 'Bump to #{version} [ci skip]'`
      puts "# Creating tag #{version}"
      puts `git tag #{version}`
      puts `git push origin #{version}`
      puts `git push origin #{current_branch}`
    rescue
      puts "ERROR: Tag '#{version}' already exists"
      exit 1
    end
  end
end
task :publish => [
  "publish:check_requirements",
  "publish:configure_version",
  "build:clean",
  "build:all",
  "publish:push_gem_packages",
  "publish:tag_and_push_version"
]

desc "Install the AppSignal gem, extension and all possible dependencies."
task :install => "extension:install" do
  Bundler.with_clean_env do
    GEMFILES.each do |gemfile|
      system "bundle --gemfile gemfiles/#{gemfile}.gemfile"
    end
  end
end

task :spec_all_gemfiles do
  GEMFILES.each do |gemfile|
    puts "Running tests for #{gemfile}"
    unless system("env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec")
      raise "Not successful"
    end
  end
end

task :generate_bundle_and_spec_all do
  VERSION_MANAGERS.each do |version_manager, switch_command|
    out = []
    out << if version_manager == :rvm
             "#!/bin/bash --login"
           else
             "#!/bin/sh"
           end
    out << "rm -f .ruby-version"
    out << "echo 'Using #{version_manager}'"
    RUBY_VERSIONS.each do |version|
      short_version = version.split("-").first
      out << "echo 'Switching to #{short_version}'"
      out << "#{switch_command.call(version)} || { echo 'Switching Ruby failed'; exit 1; }"
      out << "ruby -v"
      out << "echo 'Compiling extension'"
      out << "cd ext && rm -f appsignal-agent appsignal_extension.bundle appsignal.h libappsignal.a Makefile && ruby extconf.rb && make && cd .."
      GEMFILES.each do |gemfile|
        next if EXCLUSIONS[gemfile] && EXCLUSIONS[gemfile].include?(short_version)
        out << "echo 'Bundling #{gemfile} in #{short_version}'"
        out << "bundle --quiet --gemfile gemfiles/#{gemfile}.gemfile || { echo 'Bundling failed'; exit 1; }"
        out << "echo 'Running #{gemfile} in #{short_version}'"
        out << "env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec || { echo 'Running specs failed'; exit 1; }"
      end
    end
    out << "rm -f .ruby-version"
    out << "echo 'Successfully ran specs for all environments'"

    script = "bundle_and_spec_all_#{version_manager}"
    FileUtils.rm_f(script)
    File.open(script, "w") do |file|
      file.write out.join("\n")
    end
    File.chmod(0o775, script)
    puts "Generated #{script}"
  end
end

task :console do
  require "irb"
  require "irb/completion"
  require "appsignal"

  Appsignal.config = Appsignal::Config.new(".", :console)

  ARGV.clear
  IRB.start
end

namespace :extension do
  desc "Install the AppSignal gem extension"
  task :install => :clean do
    if RUBY_PLATFORM == "java"
      system "cd ext && rake"
    else
      system "cd ext && ruby extconf.rb && make clean && make"
    end
  end

  desc "Clean the AppSignal gem extension directory of installation artifacts"
  task :clean do
    system <<-COMMAND
      cd ext &&
        rm -f appsignal.bundle \
          appsignal-agent \
          appsignal.h \
          appsignal_extension.o \
          appsignal_extension.bundle \
          install.log \
          libappsignal.a \
          appsignal.version \
          Makefile \
          mkmf.log
      COMMAND
  end
end

begin
  require "rspec/core/rake_task"
  desc "Run the AppSignal gem test suite."
  RSpec::Core::RakeTask.new :test
rescue LoadError # rubocop:disable Lint/HandleExceptions
  # When running rake install, there is no RSpec yet.
end

task :default => [:generate_bundle_and_spec_all, :spec_all_gemfiles]
