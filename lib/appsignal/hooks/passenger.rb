module Appsignal
  class Hooks
    # @api private
    class PassengerHook < Appsignal::Hooks::Hook
      def dependencies_present?
        defined?(::PhusionPassenger)
      end

      def install
        ::PhusionPassenger.on_event(:starting_worker_process) do |_forked|
          Appsignal.forked
        end

        ::PhusionPassenger.on_event(:stopping_worker_process) do
          Appsignal.stop("passenger")
        end
      end
    end
  end
end

Appsignal::Hooks.register(:passenger, Appsignal::Hooks::PassengerHook)
