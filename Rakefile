task :publish do
  NAME = 'appsignal'
  VERSION_FILE = 'lib/appsignal/version.rb'

  def publish_gem
    puts '# Building Gemspec'
    puts `gem build #{NAME}.gemspec`
    puts '# Publishing Gem'
    puts `gem push #{gem_name}`
  end

  def create_and_push_tag
    begin
      puts `git commit -m 'Bump to #{version} [ci skip]'`
      puts "# Creating tag #{version}"
      puts `git tag #{version}`
      puts `git push origin #{version}`
    rescue
      raise "Tag: '#{version}' already exists"
    end
  end

  def changes
    git_status_to_array(`git status -s -u `)
  end

  def gem_name
    @gem_name ||= git_status_to_array(`git status -s -u`).last
  end

  def gem_version
    @gem_version ||= gem_name.gsub(/^.*(\d+\.\d+\.\d+).gemspec$/,'\1')
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
    publish_gem
    create_and_push_tag
  else
    raise "Actually change the version in: #{VERSION_FILE}"
  end

end
