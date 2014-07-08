GEMFILES = %w(
  capistrano2
  capistrano3
  no_dependencies
  rails-3.0
  rails-3.1
  rails-3.2
  rails-4.0
  rails-4.1
  sinatra
)

RUBY_VERSIONS = %w(
  1.9.3-p429
  2.0.0-p451
  2.1.2
  jruby-1.7.9
  rbx-2.2.9
)

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
      puts `git push origin master`
      puts `git push appsignal master`
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

task :bundle do
  GEMFILES.each do |gemfile|
    system "bundle --gemfile gemfiles/#{gemfile}.gemfile"
  end
end

task :spec do
  GEMFILES.each do |gemfile|
    puts "Running #{gemfile}"
    raise 'Not successful' unless system("env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec")
  end
end

task :bundle_and_spec_all do
  start_time = Time.now
  RUBY_VERSIONS.each do |version|
    puts "Switching to #{version}"
    system "rbenv local #{version}"
    GEMFILES.each do |gemfile|
      puts "Bundling #{gemfile} in #{version}"
      system "bundle --quiet --gemfile gemfiles/#{gemfile}.gemfile"
      puts "Running #{gemfile} in #{version}"
      raise 'Not successful' unless system("env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec")
    end
  end
  system 'rm .ruby-version'
  puts "Successfully ran specs for all environments in #{Time.now - start_time} seconds"
end

task :console do
  require 'irb'
  require 'irb/completion'
  require 'appsignal'

  Appsignal.config = Appsignal::Config.new('.', :console)

  ARGV.clear
  IRB.start
end
