# frozen_string_literal: true

module Appsignal
  module Integrations
    module QuePlugin
      def self.included(base)
        base.class_eval do
          def _run_with_appsignal(*)
            local_attrs = respond_to?(:que_attrs) ? que_attrs : attrs
            env = {
              :metadata    => {
                :id        => local_attrs[:job_id] || local_attrs[:id],
                :queue     => local_attrs[:queue],
                :run_at    => local_attrs[:run_at].to_s,
                :priority  => local_attrs[:priority],
                :attempts  => local_attrs[:error_count].to_i
              },
              :params => local_attrs[:args]
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
              transaction.set_action "#{local_attrs[:job_class]}#run"
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
