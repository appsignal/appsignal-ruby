require 'appsignal/version'

task :publish do
  NAME = 'appsignal'
  VERSION_FILE = 'lib/appsignal/version.rb'

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
    git_status_to_array(`git status -s -u `)
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
    build_and_push_gem
    create_and_push_tag
  else
    raise "Actually change the version in: #{VERSION_FILE}"
  end
end
