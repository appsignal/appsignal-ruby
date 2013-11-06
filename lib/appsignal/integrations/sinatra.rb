Appsignal.logger.info('Loading Sinatra integration')

app_settings = ::Sinatra::Application.settings
Appsignal.config = Appsignal::Config.new(
  app_settings.root,
  app_settings.environment.to_s
)

Appsignal.logger = Logger.new(File.join(app_settings.root, 'appsignal.log')).tap do |l|
  l.level = Logger::DEBUG
end
Appsignal.flush_in_memory_log

if Appsignal.active?
  Appsignal.start
  ::Sinatra::Application.use(Appsignal::Rack::Listener)
  ::Sinatra::Application.use(Appsignal::Rack::Instrumentation)
end
