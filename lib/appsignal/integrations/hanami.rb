# frozen_string_literal: true

require "appsignal"
require "appsignal/rack/hanami_instrumentation"

hanami_app_config = ::Hanami.app.config
Appsignal.config = Appsignal::Config.new(
  hanami_app_config.root || Dir.pwd,
  hanami_app_config.env
)

Appsignal.start_logger
Appsignal.start

if Appsignal.active?
  hanami_app_config.middleware.use Appsignal::Rack::HanamiInstrumentation
end
