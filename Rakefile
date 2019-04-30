require "bundler"
require "rubygems/package_task"
require "fileutils"

VERSION_MANAGERS = {
  :chruby => {
    :env => "#!/bin/bash\nsource /usr/local/opt/chruby/share/chruby/chruby.sh",
    :switch_command => ->(version) { "chruby #{version}" }
  },
  :rbenv => {
    :env => "#!/bin/bash",
    :switch_command => ->(version) { "rbenv local #{version}" }
  },
  :rvm => {
    :env => "#!/bin/bash --login",
    :switch_command => ->(version) { "rvm use --default #{version}" }
  }
}.freeze

namespace :build_matrix do
  namespace :travis do
    task :generate do
      yaml = YAML.load_file("build_matrix.yml")
      matrix = yaml["matrix"]
      defaults = matrix["defaults"]

      builds = []
      matrix["ruby"].each do |ruby|
        ruby_version = ruby["ruby"]
        gemset_for_ruby(ruby, matrix).each do |gem|
          next if excluded_for_ruby?(gem, ruby)

          env = ""
          rubygems = gem["rubygems"] || ruby["rubygems"] || defaults["rubygems"]
          env = "_RUBYGEMS_VERSION=#{rubygems}" if rubygems
          bundler = gem["bundler"] || ruby["bundler"] || defaults["bundler"]
          env += " _BUNDLER_VERSION=#{bundler}" if bundler

          builds << {
            "rvm" => ruby_version,
            "gemfile" => "gemfiles/#{gem["gem"]}.gemfile",
            "env" => env
          }
        end
      end
      travis = yaml["travis"]
      travis["matrix"]["include"] = travis["matrix"]["include"] + builds

      header = "# DO NOT EDIT\n" \
        "# This is a generated file by the `rake build_matrix:travis:generate` task.\n" \
        "# See `build_matrix.yml` for the build matrix.\n" \
        "# Generate this file with `rake build_matrix:travis:generate`.\n"
      generated_yaml = header + YAML.dump(travis)
      File.write(".travis.yml", generated_yaml)
      puts "Generated `.travis.yml`"
      puts "Build count: #{builds.length}"
    end

    task :validate => :generate do
      `git status | grep .travis.yml 2>&1`
      if $?.exitstatus.zero? # rubocop:disable Style/SpecialGlobalVars
        puts "The `.travis.yml` is modified. The changes were not committed."
        puts "Please run `rake build_matrix:travis:generate` and commit the changes."
        exit 1
      end
    end
  end

  namespace :local do
    task :generate do
      yaml = YAML.load_file("build_matrix.yml")
      matrix = yaml["matrix"]
      defaults = matrix["defaults"]

      VERSION_MANAGERS.each do |version_manager, config|
        out = []
        out << config[:env]
        out << "rm -f .ruby-version"
        out << "echo 'Using #{version_manager}'"
        matrix["ruby"].each do |ruby|
          ruby_version = ruby["ruby"]
          out << "echo 'Switching to #{ruby_version}'"
          out << "#{config[:switch_command].call(ruby_version)} || { echo 'Switching Ruby failed'; exit 1; }"
          out << "ruby -v"
          out << "echo 'Compiling extension'"
          out << "./support/bundler_wrapper exec rake extension:install"
          out << "rm -f gemfiles/*.gemfile.lock"
          gemset_for_ruby(ruby, matrix).each do |gem|
            next if excluded_for_ruby?(gem, ruby)
            gemfile = gem["gem"]
            out << "echo 'Bundling #{gemfile} in #{ruby_version}'"
            rubygems = gem["rubygems"] || ruby["rubygems"] || defaults["rubygems"]
            rubygems_version = "env _RUBYGEMS_VERSION=#{rubygems_version}" if rubygems
            bundler = gem["bundler"] || ruby["bundler"] || defaults["bundler"]
            bundler_version = "env _BUNDLER_VERSION=#{bundler}" if bundler
            gemfile_env = "env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile"
            out << "#{bundler_version} #{rubygems_version} ./support/install_deps"
            out << "#{bundler_version} #{gemfile_env} ./support/bundler_wrapper install --quiet || { echo 'Bundling failed'; exit 1; }"
            out << "echo 'Running #{gemfile} in #{ruby_version}'"
            out << "#{bundler_version} #{gemfile_env} ./support/bundler_wrapper exec rspec || { echo 'Running specs failed'; exit 1; }"
          end
          out << ""
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
  end

  def gemset_for_ruby(ruby, matrix)
    gems = matrix["gems"]
    if ruby["gems"]
      # Only a specific gemset for this Ruby
      selected_gems = matrix["gemsets"].fetch(ruby["gems"])
      gems.select { |g| selected_gems.include?(g["gem"]) }
    else
      # All gems for this Ruby
      gems
    end
  end

  def excluded_for_ruby?(gem, ruby)
    (gem.dig("exclude", "ruby") || []).include?(ruby["ruby"])
  end
end

namespace :build do
  def base_gemspec
    eval(File.read("appsignal.gemspec")) # rubocop:disable Security/Eval
  end

  def modify_base_gemspec
    base_gemspec.tap do |s|
      yield s
    end
  end

  namespace :ruby do
    # Extension default set in `appsignal.gemspec`
    Gem::PackageTask.new(base_gemspec) { |_pkg| }
  end

  namespace :jruby do
    spec = modify_base_gemspec do |s|
      s.platform = "java"
      # Override extensions config with JRuby extension installer
      # Default set in `appsignal.gemspec`
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

    system "$EDITOR #{VERSION_FILE}"
    unless changes.member?(VERSION_FILE)
      puts "ERROR: Please actually change the gem version in: #{VERSION_FILE}"
      exit 1
    end

    puts "\n# Updating the changelog"
    system "$EDITOR #{CHANGELOG_FILE}"
  end

  task :push_gem_packages do
    puts "\n# Pushing gem packages"
    Dir.chdir("#{File.dirname(__FILE__)}/pkg") do
      Dir["*.gem"].each do |gem_package|
        puts "## Publishing gem package: #{gem_package}"
        system "gem push #{gem_package}"
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

  task :build => "build:clean" do
    # Shell out to build so the new version is loaded in the gemspec.
    `rake build:all`
  end
end
task :publish => [
  "publish:check_requirements",
  "publish:configure_version",
  "publish:build",
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
          appsignal_extension.so \
          appsignal_extension.bundle \
          install.report \
          libappsignal.* \
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
