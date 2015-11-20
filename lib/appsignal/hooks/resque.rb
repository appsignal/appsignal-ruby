module Appsignal
  class Hooks
    module ResquePlugin
      def around_perform_resque_plugin(*args)
        Appsignal.monitor_single_transaction(
          'perform_job.resque',
          :class => self.to_s,
          :method => 'perform'
        ) do
          yield
        end
      end
    end

    class ResqueHook < Appsignal::Hooks::Hook
      register :resque

      def dependencies_present?
        defined?(::Resque)
      end

      def install
        # Extend the default job class with AppSignal instrumentation
        ::Resque::Job.send(:extend, Appsignal::Hooks::ResquePlugin)
      end
    end
  end
end
