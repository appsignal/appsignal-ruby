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
