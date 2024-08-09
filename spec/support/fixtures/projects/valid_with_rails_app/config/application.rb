require "rails"

module MyApp
  class Application < Rails::Application
    config.active_support.deprecation = proc { |message, stack| }
    config.eager_load = false

    def self.initialize!
      # Prevent errors about Rails being initialized more than once
      return if defined?(@initialized)

      super
      @initialized = true
    end
  end
end
