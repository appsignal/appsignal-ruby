# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class ActiveSupportEventReporterHook < Appsignal::Hooks::Hook
      register :active_support_event_reporter

      def dependencies_present?
        defined?(::ActiveSupport::EventReporter) &&
          Appsignal.config &&
          Appsignal.config[:enable_active_support_event_reporter]
      end

      def install
        require "appsignal/integrations/active_support_event_reporter"
        Rails.event.subscribe(Appsignal::Integrations::ActiveSupportEventReporter::Subscriber.new())
      end
    end
  end
end
