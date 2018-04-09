module Appsignal
  class Hooks
    # @api private
    class CelluloidHook < Appsignal::Hooks::Hook
      def dependencies_present?
        defined?(::Celluloid)
      end

      def install
        # Some versions of Celluloid have race conditions while exiting
        # that can result in a dead lock. We stop appsignal before shutting
        # down Celluloid so we're sure our thread does not aggravate this situation.
        # This way we also make sure any outstanding transactions get flushed.

        ::Celluloid.class_eval do
          class << self
            alias shutdown_without_appsignal shutdown

            def shutdown
              Appsignal.stop("celluloid")
              shutdown_without_appsignal
            end
          end
        end
      end
    end
  end
end

Appsignal::Hooks.register(:celluloid, Appsignal::Hooks::CelluloidHook)
