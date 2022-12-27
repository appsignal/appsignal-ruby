# frozen_string_literal: true

require "appsignal"
# require "appsignal/rack/hanami_instrumentation"

hanami_app_config = ::Hanami.app.config
Appsignal.config = Appsignal::Config.new(
  hanami_app_config.root || Dir.pwd,
  hanami_app_config.env
)

Appsignal.start_logger
Appsignal.start

module HanamiIntegration
  def call(env)
    params = ::Hanami::Action::BaseParams.new(env)
    request = ::Hanami::Action::Request.new(
      :env => env,
      :params => params,
      :sessions_enabled => true
    )

    transaction = Appsignal::Transaction.create(
      SecureRandom.uuid,
      Appsignal::Transaction::HTTP_REQUEST,
      request
    )

    begin
      Appsignal.instrument("process_action.hanami") do
        super
      end
    rescue Exception => error # rubocop:disable Lint/RescueException
      transaction.set_error(error)
      raise error
    ensure
      transaction.params = request.params.to_h
      transaction.set_action_if_nil(self.class.name)
      transaction.set_metadata("path", request.path)
      transaction.set_metadata("method", request.request_method)
      transaction.set_http_or_background_queue_start
      Appsignal::Transaction.complete_current!
    end

  end
end

if Appsignal.active?
  # hanami_app_config.middleware.use Appsignal::Rack::HanamiInstrumentation
  ::Hanami::Action.prepend(HanamiIntegration)
end
