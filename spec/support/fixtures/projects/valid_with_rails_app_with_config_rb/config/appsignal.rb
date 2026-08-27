# The demo and diagnose commands have to load this Rails application before they
# read this file. Referencing a Rails constant here fails when they do not.
Rails.application

Appsignal.configure do |config|
  config.activate_if_environment(:production, :development, :test)
  config.name = "TestApp"
  config.push_api_key = "abc"
  config.enable_minutely_probes = false
end
