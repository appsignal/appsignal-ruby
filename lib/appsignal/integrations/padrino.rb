# frozen_string_literal: true

require "appsignal"

module Appsignal
  module Integrations
    # @api private
    module PadrinoPlugin
      def self.init
        Appsignal.internal_logger.debug("Loading Padrino (#{Padrino::VERSION}) integration")

        root = Padrino.mounted_root
        Appsignal.config = Appsignal::Config.new(root, Padrino.env)

        Appsignal.start_logger
        Appsignal.start
      end
    end
  end
end

module Appsignal::Integrations::PadrinoIntegration
  def route!(base = settings, pass_block = nil)
    return super if !Appsignal.active? || env["sinatra.static_file"]

    transaction = Appsignal::Transaction.create(
      SecureRandom.uuid,
      Appsignal::Transaction::HTTP_REQUEST,
      request
    )
    begin
      Appsignal.instrument("process_action.padrino") do
        super
      end
    rescue Exception => error # rubocop:disable Lint/RescueException
      transaction.set_error(error)
      raise error
    ensure
      transaction.set_action_if_nil(get_payload_action(request))
      transaction.set_metadata("path", request.path)
      transaction.set_metadata("method", request.request_method)
      transaction.set_http_or_background_queue_start
      Appsignal::Transaction.complete_current!
    end
  end

  private

  def get_payload_action(request)
    # Short-circut is there's no request object to obtain information from
    return settings.name.to_s unless request

    # Newer versions expose the action / controller on the request class.
    # Newer versions also still expose a route_obj so we must prioritize the
    # action/fullpath methods.
    # The `request.action` and `request.controller` values are `nil` when a
    # endpoint is not found, `""` if not specified by the user.
    controller_name = request.controller if request.respond_to?(:controller)
    action_name = request.action if request.respond_to?(:action)
    action_name ||= ""

    return "#{settings.name}:#{controller_name}##{action_name}" unless action_name.empty?

    # Older versions of Padrino work with a route object
    if request.respond_to?(:route_obj) && request.route_obj
      return "#{settings.name}:#{request.route_obj.original_path}"
    end

    # Fall back to the application name if we haven't found an action name in
    # any previous methods.
    "#{settings.name}#unknown"
  end
end

Padrino::Application.prepend Appsignal::Integrations::PadrinoIntegration

Padrino.after_load do
  Appsignal::Integrations::PadrinoPlugin.init
end
