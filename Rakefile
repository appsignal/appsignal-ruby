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
  system 'bundle --gemfile gemfiles/capistrano2.gemfile'
  system 'bundle --gemfile gemfiles/capistrano3.gemfile'
  system 'bundle --gemfile gemfiles/no_dependencies.gemfile'
  system 'bundle --gemfile gemfiles/rails-3.0.gemfile'
  system 'bundle --gemfile gemfiles/rails-3.1.gemfile'
  system 'bundle --gemfile gemfiles/rails-3.2.gemfile'
  system 'bundle --gemfile gemfiles/rails-4.0.gemfile'
  system 'bundle --gemfile gemfiles/rails-4.1.gemfile'
  system 'bundle --gemfile gemfiles/sinatra.gemfile'
end

task :spec do
  puts 'Running capistrano2'
  system 'env BUNDLE_GEMFILE=gemfiles/capistrano2.gemfile bundle exec rspec'

  puts 'Running capistrano3'
  system 'env BUNDLE_GEMFILE=gemfiles/capistrano3.gemfile bundle exec rspec'

  puts 'Running no dependencies'
  system 'env BUNDLE_GEMFILE=gemfiles/no_dependencies.gemfile bundle exec rspec'

  puts 'Running rails-3.0'
  system 'env BUNDLE_GEMFILE=gemfiles/rails-3.0.gemfile bundle exec rspec'

  puts 'Running rails-3.1'
  system 'env BUNDLE_GEMFILE=gemfiles/rails-3.1.gemfile bundle exec rspec'

  puts 'Running rails-3.2'
  system 'env BUNDLE_GEMFILE=gemfiles/rails-3.2.gemfile bundle exec rspec'

  puts 'Running rails-4.0'
  system 'env BUNDLE_GEMFILE=gemfiles/rails-4.0.gemfile bundle exec rspec'

  puts 'Running rails-4.1'
  system 'env BUNDLE_GEMFILE=gemfiles/rails-4.1.gemfile bundle exec rspec'

  puts 'Running sinatra'
  system 'env BUNDLE_GEMFILE=gemfiles/sinatra.gemfile bundle exec rspec'
end

task :console do
  require 'irb'
  require 'irb/completion'
  require 'appsignal'

  Appsignal.config = Appsignal::Config.new('.', :console)

  ARGV.clear
  IRB.start
end
