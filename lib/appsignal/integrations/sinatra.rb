require 'appsignal'
require 'appsignal/rack/sinatra_instrumentation'

Appsignal.logger.info("Loading Sinatra (#{Sinatra::VERSION}) integration")

app_settings = ::Sinatra::Application.settings
Appsignal.config = Appsignal::Config.new(
  app_settings.root,
  app_settings.environment
)

Appsignal.start_logger(app_settings.root)

Appsignal.start

if Appsignal.active?
  ::Sinatra::Application.use(Appsignal::Rack::Listener)
  ::Sinatra::Application.use(Appsignal::Rack::SinatraInstrumentation)
end
