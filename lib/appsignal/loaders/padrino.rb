# frozen_string_literal: true

module Appsignal
  module Loaders
    class PadrinoLoader < Loader
      register :padrino

      def on_load
        register_config_defaults(
          :root_path => Padrino.mounted_root,
          :env => Padrino.env
        )
      end

      def on_start
        require "appsignal/rack/sinatra_instrumentation"

        Padrino::Application.prepend(Appsignal::Loaders::PadrinoLoader::PadrinoIntegration)

        Padrino.before_load do
          Padrino.use Appsignal::Rack::EventMiddleware
          Padrino.use Appsignal::Rack::SinatraBaseInstrumentation,
            :instrument_event_name => "process_action.padrino"
        end
      end

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
end
