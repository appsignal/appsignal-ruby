Appsignal.configure do |config|
  config.activate_if_environment(:production, :development, :test)
  config.name = "TestApp"
  config.push_api_key = "abc"
  config.enable_minutely_probes = false
end
