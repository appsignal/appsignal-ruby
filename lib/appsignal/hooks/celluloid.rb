# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class CelluloidHook < Appsignal::Hooks::Hook
      register :celluloid

      def dependencies_present?
        defined?(::Celluloid)
      end

      def install
        # Some versions of Celluloid have race conditions while exiting
        # that can result in a dead lock. We stop appsignal before shutting
        # down Celluloid so we're sure our thread does not aggravate this situation.
        # This way we also make sure any outstanding transactions get flushed.

        Celluloid.singleton_class.send(:prepend, Module.new do
          def shutdown
            Appsignal.stop("celluloid")
            super
          end
        end)
      end
    end
  end
end
