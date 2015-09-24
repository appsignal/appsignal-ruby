if defined?(::Celluloid)
  Appsignal.logger.info('Loading Celluloid integration')

  # Some versions of Celluloid have race conditions while exiting
  # that can result in a dead lock. We stop appsignal before shutting
  # down Celluloid so we're sure our thread does not aggravate this situation.

  ::Celluloid.class_eval do
    class << self
      alias shutdown_without_appsignal shutdown

      def shutdown
        Appsignal.stop_extension
        shutdown_without_appsignal
      end
    end
  end
end
