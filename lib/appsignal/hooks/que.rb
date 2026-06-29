# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class QueHook < Appsignal::Hooks::Hook
      register :que

      def dependencies_present?
        defined?(::Que::Job)
      end

      def install
        require "appsignal/integrations/que"
        ::Que::Job.prepend Appsignal::Integrations::QuePlugin
        ::Que::Job.singleton_class.prepend Appsignal::Integrations::QueClientPlugin

        # `bulk_enqueue` exists only on Que 2+; don't define one where it's absent.
        if ::Que::Job.respond_to?(:bulk_enqueue)
          ::Que::Job.singleton_class.prepend Appsignal::Integrations::QueBulkClientPlugin
        end

        ::Que.error_notifier = proc do |error, _job|
          Appsignal::Transaction.current.set_error(error)
        end
      end
    end
  end
end
