# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
MyApp::Application.initialize!

# Asserted from the diagnose spec
Appsignal.configure do |config|
  config.ignore_actions = ["Action from DSL"]
end
