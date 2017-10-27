module Appsignal
  module Integrations
    module QuePlugin

      def self.included(base)
        base.class_eval do

          def _run_with_appsignal
            cls = attrs[:job_class]
            cls = attrs[:args].last['job_class'] if cls == "ActiveJob::QueueAdapters::QueAdapter::JobWrapper"
            Appsignal.monitor_transaction(
              'perform_job.que',
              :class    => cls,
              :method   => 'run',
              :metadata => {
                :id        => attrs[:job_id],
                :queue     => attrs[:queue],
                :run_at    => attrs[:run_at].to_s,
                :priority  => attrs[:priority],
                :attempts  => attrs[:error_count].to_i
              },
              :params => attrs[:args]
            ) { _run_without_appsignal }
          end

          alias_method :_run_without_appsignal, :_run
          alias_method :_run, :_run_with_appsignal
        end
      end

    end
  end
end
