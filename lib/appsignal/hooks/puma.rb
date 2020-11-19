# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class PumaHook < Appsignal::Hooks::Hook
      register :puma

      def dependencies_present?
        defined?(::Puma)
      end

      def install
        if ::Puma.respond_to?(:stats) && !defined?(APPSIGNAL_PUMA_PLUGIN_LOADED)
          # Only install the minutely probe if a user isn't using our Puma
          # plugin, which lives in `lib/puma/appsignal.rb`. This plugin defines
          # the {APPSIGNAL_PUMA_PLUGIN_LOADED} constant.
          #
          # We prefer people use the AppSignal Puma plugin. This fallback is
          # only there when users relied on our *magic* integration.
          #
          # Using the Puma plugin, the minutely probe thread will still run in
          # Puma workers, for other non-Puma probes, but the Puma probe only
          # runs in the Puma main process.
          # For more information:
          # https://docs.appsignal.com/ruby/integrations/puma.html
          Appsignal::Minutely.probes.register :puma, ::Appsignal::Probes::PumaProbe
        end

        return unless defined?(::Puma::Cluster)
        # For clustered mode with multiple workers
        ::Puma::Cluster.send(:prepend, Module.new do
          def stop_workers
            Appsignal.stop("puma cluster")
            super
          end
        end)
      end
    end
  end
end
