# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module QuePlugin
      def _run(*args)
        transaction =
          Appsignal::Transaction.create(Appsignal::Transaction::BACKGROUND_JOB)

        begin
          Appsignal.instrument("perform_job.que") { super }
        rescue Exception => error # rubocop:disable Lint/RescueException
          transaction.set_error(error)
          raise error
        ensure
          local_attrs = respond_to?(:que_attrs) ? que_attrs : attrs
          transaction.set_action_if_nil("#{local_attrs[:job_class]}#run")
          transaction.add_params_if_nil do
            {
              :arguments => local_attrs[:args]
            }.tap do |hash|
              hash[:keyword_arguments] = local_attrs[:kwargs] if local_attrs.key?(:kwargs)
            end
          end
          transaction.add_tags(
            "id" => local_attrs[:job_id] || local_attrs[:id],
            "queue" => local_attrs[:queue],
            "run_at" => local_attrs[:run_at].to_s,
            "priority" => local_attrs[:priority],
            "attempts" => local_attrs[:error_count].to_i
          )
          Appsignal::Transaction.complete_current!
        end
      end
    end
  end
end
