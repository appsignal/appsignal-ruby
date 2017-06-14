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

Dir[File.join(APPSIGNAL_SPEC_DIR, "support/helpers", "*.rb")].each do |f|
  require f
end
Dir[File.join(APPSIGNAL_SPEC_DIR, "support/mocks", "*.rb")].each do |f|
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

puts "Running specs in #{RUBY_VERSION} on #{RUBY_PLATFORM}\n\n"

# Add way to clear subscribers between specs
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

RSpec.configure do |config|
  config.include DirectoryHelper
  config.include StdStreamsHelper
  config.include ConfigHelpers
  config.include EnvHelpers
  config.include TimeHelpers
  config.include TransactionHelpers
  config.include ApiRequestHelper
  config.include SystemHelpers
  config.extend DependencyHelper

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
    appsignal_key_prefixes = %w(APPSIGNAL_ _APPSIGNAL_)
    env_keys = ENV.keys.select { |key| key.start_with?(*appsignal_key_prefixes) }
    env_keys.each { |key| ENV.delete(key) }

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
