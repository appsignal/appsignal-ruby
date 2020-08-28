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
        ::Puma::Cluster.class_eval do
          alias stop_workers_without_appsignal stop_workers

          def stop_workers
            Appsignal.stop("puma cluster")
            stop_workers_without_appsignal
          end
        end
      end
    end
  end
end
