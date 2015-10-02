if defined?(::Que)
  Appsignal.logger.info('Loading Que integration')

  module Appsignal
    module Integrations
      module QuePlugin
        def self.included(base)
          base.class_eval do

            def _run_with_appsignal
              Appsignal.monitor_transaction(
                'perform_job.que',
                :class    => attrs[:job_class],
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

  class Que::Job
    # For Ruby 2+ prepend would be more beautiful, but we support 1.9.3 too.
    include Appsignal::Integrations::QuePlugin
  end
end
