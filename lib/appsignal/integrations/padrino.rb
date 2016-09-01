require 'appsignal'

module Appsignal::Integrations
  module PadrinoPlugin
    def self.init
      Appsignal.logger.info("Loading Padrino (#{Padrino::VERSION}) integration")

      root             = Padrino.mounted_root
      Appsignal.config = Appsignal::Config.new(
        root,
        ENV.fetch('APPSIGNAL_APP_ENV'.freeze, Padrino.env.to_s),
        :log_path => File.join(root, 'log')
      )

      Appsignal.start_logger
      Appsignal.start
    end
  end
end

module Padrino::Routing::InstanceMethods
  alias route_without_appsignal route!

  def route!(base=settings, pass_block=nil)
    if !Appsignal.active? || env['sinatra.static_file']
      route_without_appsignal(base, pass_block)
      return
    end

    transaction = Appsignal::Transaction.create(
      SecureRandom.uuid,
      Appsignal::Transaction::HTTP_REQUEST,
      request
    )
    begin
      ActiveSupport::Notifications.instrument('process_action.padrino') do
        route_without_appsignal(base, pass_block)
      end
    rescue => error
      transaction.set_error(error)
      raise error
    ensure
      transaction.set_action(get_payload_action(request))
      transaction.set_metadata('path', request.path)
      transaction.set_metadata('method', request.request_method)
      transaction.set_http_or_background_queue_start
      Appsignal::Transaction.complete_current!
    end
  end

  def get_payload_action(request)
    # Short-circut is there's no request object to obtain information from
    return "#{settings.name}" if request.nil?

    # Older versions of Padrino work with a route object
    route_obj = defined?(request.route_obj) && request.route_obj
    if route_obj && route_obj.respond_to?(:original_path)
      return "#{settings.name}:#{request.route_obj.original_path}"
    end

    # Newer versions expose the action / controller on the request class
    request_data = request.respond_to?(:action) ? request.action : request.fullpath
    "#{settings.name}:#{request.controller}##{request_data}"
  end
end

Padrino.after_load do
  Appsignal::Integrations::PadrinoPlugin.init
end
