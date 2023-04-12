# frozen_string_literal: true

require "bundler"
require "rubygems/package_task"
require "fileutils"
require "yaml"

VERSION_MANAGERS = {
  :chruby => {
    :env => "#!/bin/bash\nsource /usr/local/opt/chruby/share/chruby/chruby.sh",
    :switch_command => lambda { |version| "chruby #{version}" }
  },
  :rbenv => {
    :env => "#!/bin/bash",
    :switch_command => lambda { |version| "rbenv local #{version}" }
  },
  :rvm => {
    :env => "#!/bin/bash --login",
    :switch_command => lambda { |version| "rvm use --default #{version}" }
  }
}.freeze

def env_map(key, value)
  {
    "name" => key,
    "value" => value
  }
end

def build_task(matrix, ruby_version, type = nil)
  {
    "name" => "Ruby #{ruby_version}#{type ? " - #{type}" : nil}",
    "dependencies" => ["Validation"],
    "task" => {
      "prologue" => matrix["prologue"].merge(
        "commands" => matrix["prologue"]["commands"] + [
          "./support/bundler_wrapper exec rake extension:install"
        ]
      ),
      "epilogue" => matrix["epilogue"],
      "jobs" => []
    }
  }
end

def gems_with_gemfiles
  YAML.load_file("build_matrix.yml")["matrix"]["gems"].map { |g| g["gem"] }.freeze
end

namespace :build_matrix do
  namespace :semaphore do
    task :generate do
      yaml = YAML.load_file("build_matrix.yml")
      matrix = yaml["matrix"]
      defaults = matrix["defaults"]
      semaphore = yaml["semaphore"]

      builds = []
      matrix["ruby"].each do |ruby|
        ruby_version = ruby["ruby"]
        ruby_primary_block = build_task(matrix, ruby_version)
        ruby_secondary_block = build_task(matrix, ruby_version, "Gems").tap do |t|
          t["dependencies"] = ["Ruby #{ruby_version}"]
        end
        gemset_for_ruby(ruby, matrix).each do |gem|
          next unless included_for_ruby?(matrix, gem, ruby)

          env = matrix["env_vars"] + [
            env_map("RUBY_VERSION", ruby_version),
            env_map("GEMSET", gem["gem"]),
            env_map("BUNDLE_GEMFILE", "gemfiles/#{gem["gem"]}.gemfile")
          ]
          rubygems = gem["rubygems"] || ruby["rubygems"] || defaults["rubygems"]
          env << env_map("_RUBYGEMS_VERSION", rubygems) if rubygems
          bundler = gem["bundler"] || ruby["bundler"] || defaults["bundler"]
          env << env_map("_BUNDLER_VERSION", bundler) if bundler

          job = {
            "name" => "Ruby #{ruby_version} for #{gem["gem"]}",
            "env_vars" => env + ruby.fetch("env_vars", []),
            "commands" => [
              "./support/bundler_wrapper exec rake test"
            ]
          }
          if gem["gem"] == "no_dependencies"
            # Only test the failure scenarios once per Ruby version
            job["commands"] << "./support/bundler_wrapper exec rake test:failure"
            ruby_primary_block["task"]["jobs"] << job
          else
            ruby_secondary_block["task"]["jobs"] << job
          end
        end
        builds << ruby_primary_block
        builds << ruby_secondary_block if ruby_secondary_block["task"]["jobs"].count.nonzero?
      end
      semaphore["blocks"] += builds

      header = "# DO NOT EDIT\n" \
        "# This is a generated file by the `rake build_matrix:semaphore:generate` task.\n" \
        "# See `build_matrix.yml` for the build matrix.\n" \
        "# Generate this file with `rake build_matrix:semaphore:generate`.\n"
      generated_yaml = header + YAML.dump(semaphore)
      File.write(".semaphore/semaphore.yml", generated_yaml)
      puts "Generated `.semaphore/semaphore.yml`"
      puts "Task count: #{builds.length}"
      puts "Job count: #{builds.sum { |block| block["task"]["jobs"].count }}"
    end

    task :validate => :generate do
      output = `git status`
      if output.include? ".semaphore/semaphore.yml"
        puts "The `.semaphore/semaphore.yml` is modified. The changes were not committed."
        puts "Please run `rake build_matrix:semaphore:generate` and commit the changes."
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
          # rubocop:disable Layout/LineLength
          out << "#{config[:switch_command].call(ruby_version)} || { echo 'Switching Ruby failed'; exit 1; }"
          out << "ruby -v"
          out << "echo 'Compiling extension'"
          out << "./support/bundler_wrapper exec rake extension:install"
          out << "rm -f gemfiles/*.gemfile.lock"
          gemset_for_ruby(ruby, matrix).each do |gem|
            next unless included_for_ruby?(matrix, gem, ruby)

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
          # rubocop:enable Layout/LineLength
          out << ""
        end
        out << "rm -f .ruby-version"
        out << "echo 'Successfully ran specs for all environments'"

        script = "bundle_and_spec_all_#{version_manager}"
        FileUtils.rm_f(script)
        File.write(script, out.join("\n"))
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

  def included_for_ruby?(matrix, gem, ruby)
    included_rubies = gem.dig("only", "ruby") || []
    excluded_rubies = gem.dig("exclude", "ruby") || []
    if included_rubies.any? && excluded_rubies.any?
      raise "Both `only` and `exclude` config options for gem `#{gem["gem"]}` are configured. " \
        "Only use one of the two config options."
    end

    if included_rubies.any?
      # If this gem only runs on these specific Ruby version
      included_rubies.each { |version| check_if_ruby_version_exists!(matrix, version) }
      return true if included_rubies.include?(ruby["ruby"])
    else
      # If this gem is excluded from running on this Ruby version
      excluded_rubies.each { |version| check_if_ruby_version_exists!(matrix, version) }
      return true unless excluded_rubies.include?(ruby["ruby"])
    end
  end

  def check_if_ruby_version_exists!(matrix, ruby_version)
    return if matrix["ruby"].find { |ruby| ruby["ruby"] == ruby_version }

    raise "Ruby version `#{ruby_version}` is not known by the build matrix."
  end
end

namespace :build do
  def base_gemspec
    eval(File.read("appsignal.gemspec")) # rubocop:disable Security/Eval
  end

  def modify_base_gemspec(&block)
    base_gemspec.tap(&block)
  end

  def define_build_task(task_name, base_gemspec, &block)
    Gem::PackageTask.new(base_gemspec, &block)
  rescue StandardError => e
    puts "Warning: An error occurred defining `build:#{task_name}:gem` Rake task."
    puts "This task will not be availble."
    if ENV["DEBUG"]
      puts "#{e}: #{e.message}"
      puts e.backtrace
    else
      puts "For more information, run the same command with `DEBUG=true`."
    end
    puts
  end

  namespace :ruby do
    # Extension default set in `appsignal.gemspec`
    define_build_task(:ruby, base_gemspec) { |_pkg| } # rubocop:disable Lint/EmptyBlock
  end

  namespace :jruby do
    spec = modify_base_gemspec do |s|
      s.platform = "java"
      # Override extensions config with JRuby extension installer
      # Default set in `appsignal.gemspec`
      s.extensions = %w[ext/Rakefile]
      s.add_dependency "ffi"
    end

    define_build_task(:jruby, spec) { |_pkg| } # rubocop:disable Lint/EmptyBlock
  end

  desc "Build all gem versions"
  task :all => ["ruby:gem", "jruby:gem"]

  desc "Clean up all gem build artifacts"
  task :clean do
    FileUtils.rm_rf File.expand_path("pkg", __dir__)
  end
end

desc "Install the AppSignal gem, extension and all possible dependencies."
task :install => "extension:install" do
  Bundler.with_clean_env do
    gems_with_gemfiles.each do |gemfile|
      system "bundle --gemfile gemfiles/#{gemfile}.gemfile"
    end
  end
end

task :spec_all_gemfiles do
  Bundler.with_clean_env do
    gems_with_gemfiles.each do |gemfile|
      puts "Running tests for #{gemfile}"
      unless system("env BUNDLE_GEMFILE=gemfiles/#{gemfile}.gemfile bundle exec rspec")
        raise "Not successful"
      end
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
  is_jruby = defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
  excludes = []
  excludes << "spec/lib/appsignal/extension/jruby_spec.rb" unless is_jruby
  exclude_pattern = "--exclude-pattern=#{excludes.join(",")}" if excludes.any?

  desc "Run the AppSignal gem test suite."
  RSpec::Core::RakeTask.new :test do |t|
    t.rspec_opts = exclude_pattern
  end

  namespace :test do
    RSpec::Core::RakeTask.new :rspec_failure do |t|
      t.rspec_opts = "#{exclude_pattern} --tag extension_installation_failure"
    end

    desc "Intentionally fail the extension installation"
    task :prepare_failure do
      # ENV var to make sure installation fails on purpurse
      ENV["_TEST_APPSIGNAL_EXTENSION_FAILURE"] = "true"
      # Run extension installation with intentional failure
      `rake extension:install`
    end

    desc "Run the Appsignal gem test in an extension failure scenario"
    task :failure => [:prepare_failure, :rspec_failure]
  end
rescue LoadError
  # When running rake install, there is no RSpec yet.
end

task :default => [:generate_bundle_and_spec_all, :spec_all_gemfiles]
