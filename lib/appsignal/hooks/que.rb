# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class QueHook < Appsignal::Hooks::Hook
      register :que

      def dependencies_present?
        defined?(::Que::Job)
      end

      def install
        require "appsignal/integrations/que"
        ::Que::Job.prepend Appsignal::Integrations::QuePlugin

        ::Que.error_notifier = proc do |error, _job|
          Appsignal::Transaction.current.set_error(error)
        end
      end
    end
  end
end
