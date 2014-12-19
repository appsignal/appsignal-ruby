ENV['RAILS_ENV'] ||= 'test'
require 'rspec'
require 'pry'
require 'timecop'
require 'webmock/rspec'

puts "Runnings specs in #{RUBY_VERSION} on #{RUBY_PLATFORM}"

begin
  require 'rails'
  Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support/rails','*.rb'))].each {|f| require f}
  puts 'Rails present, running Rails specific specs'
  RAILS_PRESENT = true
rescue LoadError
  puts 'Rails not present, skipping Rails specific specs'
  RAILS_PRESENT = false
end

def rails_present?
  RAILS_PRESENT
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

require 'appsignal'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support/helpers','*.rb'))].each {|f| require f}

def tmp_dir
  @tmp_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'tmp'))
end

def fixtures_dir
  @fixtures_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'support/fixtures'))
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
  config.include ConfigHelpers
  config.include NotificationHelpers
  config.include TimeHelpers
  config.include TransactionHelpers

  config.before do
    ENV['PWD'] = File.expand_path(File.join(File.dirname(__FILE__), '../'))
    ENV['RAILS_ENV'] = 'test'
    ENV.delete('APPSIGNAL_PUSH_API_KEY')
    ENV.delete('APPSIGNAL_API_KEY')
  end

  config.after do
    FileUtils.rm_f(File.join(project_fixture_path, 'log/appsignal.log'))
    Appsignal.logger = nil
  end

  config.after :all do
    ActiveSupport::Notifications.notifier.clear_subscribers
  end
end

class VerySpecificError < RuntimeError
end
