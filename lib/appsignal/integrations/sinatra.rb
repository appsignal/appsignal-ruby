require 'appsignal'

Appsignal.logger.info('Loading Sinatra integration')

app_settings = ::Sinatra::Application.settings
Appsignal.config = Appsignal::Config.new(
  app_settings.root,
  app_settings.environment
)

Appsignal.start_logger(app_settings.root)

if Appsignal.active?
  Appsignal.start
  ::Sinatra::Application.use(Appsignal::Rack::Listener)
  ::Sinatra::Application.use(Appsignal::Rack::Instrumentation)
end
