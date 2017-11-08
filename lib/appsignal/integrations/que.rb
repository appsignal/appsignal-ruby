module Appsignal
  module Integrations
    module QuePlugin
      def self.included(base)
        base.class_eval do # rubocop:disable Metrics/BlockLength
          def _run_with_appsignal
            job_class = attrs[:job_class]
            if job_class == "ActiveJob::QueueAdapters::QueAdapter::JobWrapper"
              unwrapped_job = attrs[:args].first
              action_name = "#{unwrapped_job[:job_class]}#perform"
              arguments = unwrapped_job[:arguments]
            else
              action_name = "#{attrs[:job_class]}#run"
              arguments = attrs[:args]
            end

            env = {
              :metadata    => {
                :id        => attrs[:job_id],
                :queue     => attrs[:queue],
                :run_at    => attrs[:run_at].to_s,
                :priority  => attrs[:priority],
                :attempts  => attrs[:error_count].to_i
              },
              :params => arguments
            }

            request = Appsignal::Transaction::GenericRequest.new(env)

            transaction = Appsignal::Transaction.create(
              SecureRandom.uuid,
              Appsignal::Transaction::BACKGROUND_JOB,
              request
            )

            begin
              Appsignal.instrument("perform_job.que") { _run_without_appsignal }
            rescue Exception => error # rubocop:disable Lint/RescueException
              transaction.set_error(error)
              raise error
            ensure
              transaction.set_action action_name
              Appsignal::Transaction.complete_current!
            end
          end

          alias_method :_run_without_appsignal, :_run
          alias_method :_run, :_run_with_appsignal
        end
      end
    end
  end
end
