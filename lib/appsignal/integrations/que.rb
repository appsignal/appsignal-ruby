module Appsignal
  module Integrations
    module QuePlugin
      def self.included(base)
        base.class_eval do
          def _run_with_appsignal
            cls = attrs[:job_class]
            cls = attrs[:args].last["job_class"] if cls == "ActiveJob::QueueAdapters::QueAdapter::JobWrapper"

            env = {
              :metadata    => {
                :id        => attrs[:job_id],
                :queue     => attrs[:queue],
                :run_at    => attrs[:run_at].to_s,
                :priority  => attrs[:priority],
                :attempts  => attrs[:error_count].to_i
              },
              :params => attrs[:args]
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
              transaction.set_action "#{cls}#run"
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
