ENV['RAILS_ENV'] ||= 'test'
require 'rspec'
require 'rails'
require 'action_controller/railtie'

Dir[File.expand_path(File.join(File.dirname(__FILE__), 'support','**','*.rb'))].each {|f| require f}

module Rails
  class Application
  end
end

module MyApp
  class Application < Rails::Application
    config.active_support.deprecation = proc { |message, stack| }
    config.eager_load = false
  end
end

def tmp_dir
  @tmp_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'tmp'))
end

def fixtures_dir
  @fixtures_dir ||= File.expand_path(File.join(File.dirname(__FILE__), 'support/fixtures'))
end

require 'appsignal'

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
end
