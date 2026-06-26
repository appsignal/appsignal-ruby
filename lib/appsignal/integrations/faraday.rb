# frozen_string_literal: true

module Appsignal
  module Integrations
    # Prepended to `Faraday::RackBuilder#adapter`, the single point every
    # connection passes through as it finishes building its middleware stack.
    # Faraday has no global default middleware stack (unlike Excon), so patching
    # the build path is the only way to instrument every connection automatically.
    #
    # Just before the adapter (the innermost handler, where the request is sent)
    # it inserts `Faraday::Request::Instrumentation`, so the `request.faraday`
    # event fires without the user adding it themselves -- but only when
    # ActiveSupport::Notifications is loaded, since that middleware references it
    # at build time. Skipped if the user already added it.
    #
    # @!visibility private
    module FaradayRackBuilderPatch
      def adapter(*)
        if defined?(::ActiveSupport::Notifications) &&
            defined?(::Faraday::Request::Instrumentation) &&
            handlers.none? { |handler| handler.klass == ::Faraday::Request::Instrumentation }
          use(::Faraday::Request::Instrumentation)
        end
        super
      end
    end
  end
end
