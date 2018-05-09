ENV["RAILS_ENV"] ||= "test"
ENV["RACK_ENV"] ||= "test"
ENV["PADRINO_ENV"] ||= "test"

APPSIGNAL_SPEC_DIR = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(APPSIGNAL_SPEC_DIR, "support/stubs"))

Bundler.require :default
require "cgi"
require "rack"
require "rspec"
require "pry"
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
require "appsignal"

module Appsignal
  class << self
    remove_method :testing?

    def testing?
      true
    end
  end
end

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

  def spec_system_tmp_dir
    File.join(tmp_dir, "system-tmp")
  end

  config.before :context do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(spec_system_tmp_dir)
  end

  config.before do
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
  end

  config.after do
    Thread.current[:appsignal_transaction] = nil
  end

  config.after :context do
    FileUtils.rm_f(File.join(project_fixture_path, "log/appsignal.log"))
    Appsignal.config = nil
    Appsignal.logger = nil
  end
end
