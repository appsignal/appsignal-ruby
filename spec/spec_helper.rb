ENV["RAILS_ENV"] ||= "test"
ENV["RACK_ENV"] ||= "test"
ENV["PADRINO_ENV"] ||= "test"

APPSIGNAL_SPEC_DIR = File.expand_path(__dir__)
$LOAD_PATH.unshift(File.join(APPSIGNAL_SPEC_DIR, "support/stubs"))

Bundler.require :default
require "cgi"
require "rack"
require "rspec"
require "timecop"
require "webmock/rspec"

Dir[File.join(APPSIGNAL_SPEC_DIR, "support", "helpers", "*.rb")].each do |f|
  require f
end
Dir[File.join(DirectoryHelper.support_dir, "mocks", "*.rb")].each do |f|
  require f
end
Dir[File.join(DirectoryHelper.support_dir, "matchers", "*.rb")].each do |f|
  require f
end
Dir[File.join(APPSIGNAL_SPEC_DIR, "support/shared_examples", "*.rb")].each do |f|
  require f
end
if DependencyHelper.rails_present?
  Dir[File.join(DirectoryHelper.support_dir, "rails", "*.rb")].each do |f|
    require f
  end
end
if DependencyHelper.hanami2_present?
  Dir[File.join(DirectoryHelper.support_dir, "hanami", "*.rb")].each do |f|
    require f
  end
end
require "pry" if DependencyHelper.dependency_present?("pry")
require "appsignal"
# Include patches of AppSignal modules and classes to make test helpers
# available.
require File.join(DirectoryHelper.support_dir, "testing.rb")

puts "Running specs in #{RUBY_VERSION} on #{RUBY_PLATFORM}\n\n"

# Add way to clear subscribers between specs
if defined?(ActiveSupport)
  module ActiveSupport
    module Notifications
      class Fanout
        def clear_subscribers
          @subscribers.clear
          @listeners_for.clear
        end
      end
    end
  end
end

RSpec.configure do |config|
  config.include DirectoryHelper
  config.include StdStreamsHelper
  config.include ConfigHelpers
  config.include EnvHelpers
  config.include TimeHelpers
  config.include TransactionHelpers
  config.include ApiRequestHelper
  config.include SystemHelpers
  config.include LogHelpers
  config.extend DependencyHelper

  config.example_status_persistence_file_path = "spec/examples.txt"
  config.fail_if_no_examples = true
  config.exclude_pattern = "spec/integration/diagnose/**/*_spec.rb"
  config.filter_run_excluding(
    :extension_installation_failure => true,
    :jruby => !DependencyHelper.running_jruby?
  )
  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
  end
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  def spec_system_tmp_dir
    File.join(tmp_dir, "system-tmp")
  end

  config.before :context do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(spec_system_tmp_dir)
  end

  config.before do
    stop_minutely_probes
    ENV["RAILS_ENV"] ||= "test"
    ENV["RACK_ENV"] ||= "test"
    ENV["PADRINO_ENV"] ||= "test"

    # Clean environment
    appsignal_key_prefixes = %w[APPSIGNAL_ _APPSIGNAL_]
    env_keys = ENV.keys.select { |key| key.start_with?(*appsignal_key_prefixes) }
    # Always unset the diagnose variable
    # For normal Ruby this is unset in the diagnose task itself, but the JRuby
    # bug requires us to unset it using the method below as well. It's not
    # present in the ENV keys list because it's already cleared in Ruby itself
    # in the diagnose task, so add it manually to the list of to-be cleaned up
    # keys.
    env_keys << "_APPSIGNAL_DIAGNOSE"
    env_keys << "_TEST_APPSIGNAL_EXTENSION_FAILURE"
    env_keys.each do |key|
      # First set the ENV var to an empty string and then delete the key from
      # the env. We set the env var to an empty string first as JRuby doesn't
      # sync `delete` calls to extensions, making our extension think the env
      # var is still set after calling `ENV.delete`. Setting it to an empty
      # string will sort of unset it, our extension ignores env vars with an
      # empty string as a value.
      ENV[key] = ""
      ENV.delete(key)
    end

    # Stub system_tmp_dir to something in the project dir for specs
    allow(Appsignal::Config).to receive(:system_tmp_dir).and_return(spec_system_tmp_dir)

    # Unsubscribe Rails error reporter if present to avoid it reporting errors
    # multiple times through multiple subscriptions.
    if defined?(Rails) && Rails.respond_to?(:error)
      if Rails.error.respond_to?(:unsubscribe) # Future Rails version after 7.0.4.3
        Rails.error.unsubscribe(Appsignal::Integrations::RailsErrorReporterSubscriber)
      else
        Rails.error.instance_variable_get(:@subscribers)
          .delete(Appsignal::Integrations::RailsErrorReporterSubscriber)
      end
    end
  end

  # These tests are not run by default. They require a failed extension
  # installation. See the `rake test:failure` task. If a test with this tag was
  # run, run `rake extension:install` again to fix the extension installation
  # before running other tests.
  config.before :extension_installation_failure => true do
    next unless Appsignal.extension_loaded?

    raise "Extension is loaded, please run the following task and rerun the test." \
      "\n\n    rake test:prepare_failure"
  end

  # Check to see if the extension is loaded before running the specs. If the
  # extension is not loaded it can result in unexpected behavior.
  config.before do |example|
    next if Appsignal.extension_loaded?
    next if example.metadata[:extension_installation_failure]

    puts "\nWARNING: The AppSignal extension is not loaded, please run the " \
      "following task and rerun the test." \
      "\n\n    rake extension:install\n"
  end

  config.after do
    Appsignal::Testing.clear!
    clear_current_transaction!
    stop_minutely_probes
  end

  config.after :context do
    FileUtils.rm_f(File.join(project_fixture_path, "log/appsignal.log"))
    Appsignal.config = nil
    Appsignal.logger = nil
  end

  def stop_minutely_probes
    thread =
      begin
        Appsignal::Minutely.class_variable_get(:@@thread) # Fetch old thread
      rescue NameError
        nil
      end
    Appsignal::Minutely.stop
    thread&.join # Wait for old thread to exit
  end
end
