module MyApp
  class Application < Rails::Application
    config.active_support.deprecation = proc { |message, stack| }
    config.eager_load = false
  end
end
