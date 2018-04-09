module Appsignal
  class Hooks
    # @api private
    class QueHook < Appsignal::Hooks::Hook
      def dependencies_present?
        defined?(::Que::Job)
      end

      def install
        require "appsignal/integrations/que"
        ::Que::Job.send(:include, Appsignal::Integrations::QuePlugin)

        ::Que.error_notifier = proc do |error, _job|
          Appsignal::Transaction.current.set_error(error)
        end
      end
    end
  end
end

Appsignal::Hooks.register(:que, Appsignal::Hooks::QueHook)
