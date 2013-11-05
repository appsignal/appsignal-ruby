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
  puts `bundle --gemfile gemfiles/rack.gemfile`
  puts `bundle --gemfile gemfiles/rails-3.0.gemfile`
  puts `bundle --gemfile gemfiles/rails-3.1.gemfile`
  puts `bundle --gemfile gemfiles/rails-3.2.gemfile`
  puts `bundle --gemfile gemfiles/rails-4.0.gemfile`
end

task :spec do
  puts 'Running rack'
  puts `env BUNDLE_GEMFILE=gemfiles/rack.gemfile bundle exec rspec`

  puts 'Running rails-3.0'
  puts `env BUNDLE_GEMFILE=gemfiles/rails-3.0.gemfile bundle exec rspec`

  puts 'Running rails-3.1'
  puts `env BUNDLE_GEMFILE=gemfiles/rails-3.1.gemfile bundle exec rspec`

  puts 'Running rails-3.2'
  puts `env BUNDLE_GEMFILE=gemfiles/rails-3.2.gemfile bundle exec rspec`

  puts 'Running rails-4.0'
  puts `env BUNDLE_GEMFILE=gemfiles/rails-4.0.gemfile bundle exec rspec`
end
