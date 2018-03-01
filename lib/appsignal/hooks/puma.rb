# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class PumaHook < Appsignal::Hooks::Hook
      register :puma

      def dependencies_present?
        defined?(::Puma) &&
          ::Puma.respond_to?(:cli_config) &&
          ::Puma.cli_config
      end

      def install
        ::Puma.cli_config.options[:before_worker_boot] ||= []
        ::Puma.cli_config.options[:before_worker_boot] << proc do |_id|
          Appsignal.forked
        end

        ::Puma.cli_config.options[:before_worker_shutdown] ||= []
        ::Puma.cli_config.options[:before_worker_shutdown] << proc do |_id|
          Appsignal.stop("puma before_worker_shutdown")
        end

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
