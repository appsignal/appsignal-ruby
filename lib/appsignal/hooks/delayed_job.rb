module Appsignal
  class Hooks
    class DelayedJobHook < Appsignal::Hooks::Hook
      register :delayed_job

      def dependencies_present?
        defined?(::Delayed::Plugin)
      end

      def install
        # The DJ plugin is a subclass of Delayed::Plugin, so we can only
        # require this code if we're actually installing.
        require "appsignal/integrations/delayed_job_plugin"
        ::Delayed::Worker.plugins << Appsignal::Hooks::DelayedJobPlugin
      end
    end
  end
end
