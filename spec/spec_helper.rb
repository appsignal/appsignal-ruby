ENV['RAILS_ENV'] ||= 'test'
require 'rspec'
require 'pry'
require 'active_support/notifications'

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

require 'appsignal'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support/helpers','*.rb'))].each {|f| require f}

def tmp_dir
  @tmp_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'tmp'))
end

def fixtures_dir
  @fixtures_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'support/fixtures'))
end

RSpec.configure do |config|
  config.include ConfigHelpers
  config.include NotificationHelpers
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
end
