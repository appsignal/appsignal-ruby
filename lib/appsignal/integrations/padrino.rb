# frozen_string_literal: true

require "appsignal"
require "appsignal/rack/sinatra_instrumentation"

module Appsignal
  module Integrations
    # @api private
    module PadrinoPlugin
      def self.init
        Padrino::Application.prepend Appsignal::Integrations::PadrinoIntegration

        Padrino.before_load do
          Appsignal.internal_logger.debug("Loading Padrino (#{Padrino::VERSION}) integration")

          unless Appsignal.active?
            root = Padrino.mounted_root
            Appsignal.config = Appsignal::Config.new(root, Padrino.env)
            Appsignal.start
          end

          next unless Appsignal.active?

          Padrino.use ::Rack::Events, [Appsignal::Rack::EventHandler.new]
          Padrino.use Appsignal::Rack::SinatraBaseInstrumentation,
            :instrument_event_name => "process_action.padrino"
        end
      end
    end
  end
end

module Appsignal
  module Integrations
    # @api private
    module PadrinoIntegration
      def route!(base = settings, pass_block = nil)
        return super if !Appsignal.active? || env["sinatra.static_file"]

        begin
          super
        ensure
          transaction = Appsignal::Transaction.current
          transaction.set_action_if_nil(get_payload_action(request))
        end
      end

      private

      def get_payload_action(request)
        # Short-circuit is there's no request object to obtain information from
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
  end
end

Appsignal::Integrations::PadrinoPlugin.init
