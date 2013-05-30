ENV["RAILS_ENV"] ||= 'test'
require 'rspec'
require 'rails'
require 'action_controller/railtie'

Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

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

def log_file
  File.join(File.dirname(__FILE__), '../log/appsignal.log')
end

require 'appsignal'

RSpec.configure do |config|
  config.include TransactionHelpers
  config.include NotificationHelpers

  config.before :all do
    FileUtils.rm(log_file) if File.exists?(log_file)
  end
end
