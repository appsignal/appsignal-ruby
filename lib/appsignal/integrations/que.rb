if defined?(::Que)
  Appsignal.logger.info('Loading Que integration')

  module Appsignal
    module Integrations
      module QuePlugin
        def _run
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
            :params   => attrs[:args]
          ) { super }
        end
      end
    end
  end

  class Que::Job
    prepend Appsignal::Integrations::QuePlugin
  end
end
