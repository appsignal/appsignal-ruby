ENV['RAILS_ENV'] ||= 'test'
ENV['RACK_ENV'] ||= 'test'
ENV['PADRINO_ENV'] ||= 'test'

APPSIGNAL_SPEC_DIR = File.expand_path(File.dirname(__FILE__))

require 'rack'
require 'rspec'
require 'pry'
require 'timecop'
require 'webmock/rspec'

Dir[File.join(APPSIGNAL_SPEC_DIR, 'support/helpers', '*.rb')].each do |f|
  require f
end

$LOAD_PATH.unshift(File.join(APPSIGNAL_SPEC_DIR, 'support/stubs'))

puts "Running specs in #{RUBY_VERSION} on #{RUBY_PLATFORM}\n\n"

begin
  require 'rails'
  Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support/rails','*.rb'))].each {|f| require f}
  puts 'Rails present, running Rails specific specs'
  RAILS_PRESENT = true
rescue LoadError
  puts 'Rails not present, skipping Rails specific specs'
  RAILS_PRESENT = false
end

require 'appsignal'

def rails_present?
  RAILS_PRESENT
end

def active_job_present?
  require 'active_job'
  true
rescue LoadError
  false
end

def active_record_present?
  require 'active_record'
  true
rescue LoadError
  false
end

def running_jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
end

def capistrano_present?
  !! Gem.loaded_specs['capistrano']
end

def capistrano2_present?
  capistrano_present? &&
    Gem.loaded_specs['capistrano'].version < Gem::Version.new('3.0')
end

def capistrano3_present?
  capistrano_present? &&
    Gem.loaded_specs['capistrano'].version >= Gem::Version.new('3.0')
end

def sequel_present?
  require 'sequel'
  true
rescue LoadError
  false
end

def resque_present?
  require 'resque'
  true
rescue LoadError
  false
end

def sinatra_present?
  begin
    require 'sinatra'
    true
  rescue LoadError
    false
  end
end

def padrino_present?
  require 'padrino'
  true
rescue LoadError
  false
end

def grape_present?
  require 'grape'
  true
rescue LoadError
  false
end

def webmachine_present?
  require 'webmachine'
  true
rescue LoadError
  false
end

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
  config.include NotificationHelpers
  config.include TimeHelpers
  config.include TransactionHelpers

  config.before :all do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)

    # Use modifiable SYSTEM_TMP_DIR
    Appsignal::Config.send :remove_const, :SYSTEM_TMP_DIR
    Appsignal::Config.send :const_set, :SYSTEM_TMP_DIR,
      File.join(tmp_dir, 'system-tmp')
  end

  config.before do
    ENV['RAILS_ENV'] = 'test'
    ENV['PADRINO_ENV'] = 'test'

    # Clean environment
    ENV.keys.select { |key| key.start_with?('APPSIGNAL_') }.each do |key|
      ENV[key] = nil
    end
  end

  config.after do
    Thread.current[:appsignal_transaction] = nil
  end

  config.after :all do
    ActiveSupport::Notifications.notifier.clear_subscribers
    FileUtils.rm_f(File.join(project_fixture_path, 'log/appsignal.log'))
    Appsignal.config = nil
    Appsignal.logger = nil
  end
end
