require 'rspec'
require 'rails'
require 'action_controller/railtie'
require 'fixtures/liever'
module Rails
  class Application
  end
end

module MyApp
  class Application < Rails::Application
    config.active_support.deprecation = proc { |message, stack| }
  end
end

require 'appsignal'

RSpec.configure do |config|
end
