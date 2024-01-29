# frozen_string_literal: true

require "appsignal"
require "appsignal/rack/sinatra_instrumentation"

Appsignal.internal_logger.debug("Loading Sinatra (#{Sinatra::VERSION}) integration")

app_settings = ::Sinatra::Application.settings
Appsignal.config = Appsignal::Config.new(
  app_settings.root || Dir.pwd,
  app_settings.environment
)

Appsignal.start_logger
Appsignal.start

::Sinatra::Base.use(Appsignal::Rack::SinatraBaseInstrumentation) if Appsignal.active?
