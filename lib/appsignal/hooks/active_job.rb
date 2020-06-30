# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ActiveJobHook < Appsignal::Hooks::Hook
      register :active_job

      def dependencies_present?
        defined?(::ActiveJob)
      end

      def install
        ::ActiveJob::Base
          .extend ::Appsignal::Hooks::ActiveJobHook::ActiveJobClassInstrumentation
      end

      # @todo Add queue time support for Rails 6's enqueued_at. For both
      #   existing and new transactions.
      module ActiveJobClassInstrumentation
        def execute(job)
          current_transaction = Appsignal::Transaction.current
          transaction =
            if current_transaction.nil_transaction?
              # No standalone integration started before ActiveJob integration.
              # We don't have a separate integration for this QueueAdapter like
              # we do for Sidekiq.
              #
              # Prefer job_id from provider, instead of ActiveJob's internal ID.
              Appsignal::Transaction.create(
                job["provider_job_id"] || job["job_id"],
                Appsignal::Transaction::BACKGROUND_JOB,
                Appsignal::Transaction::GenericRequest.new({})
              )
            else
              current_transaction
            end

          super
        rescue Exception => exception # rubocop:disable Lint/RescueException
          transaction.set_error(exception)
          raise exception
        ensure
          if transaction
            transaction.params =
              Appsignal::Utils::HashSanitizer.sanitize(
                job["arguments"],
                Appsignal.config[:filter_parameters]
              )

            tags = { :queue => job["queue_name"] }
            provider_job_id = job["provider_job_id"]
            tags[:provider_job_id] = provider_job_id if provider_job_id
            transaction.set_tags(tags)

            transaction.set_action_if_nil(ActiveJobHelpers.action_name(job))

            if current_transaction.nil_transaction?
              # Only complete transaction if ActiveJob is not wrapped in
              # another supported integration, such as Sidekiq.
              Appsignal::Transaction.complete_current!
            end
          end
        end
      end

      module ActiveJobHelpers
        ACTION_MAILER_CLASSES = [
          "ActionMailer::DeliveryJob",
          "ActionMailer::Parameterized::DeliveryJob"
        ].freeze

        def self.action_name(job)
          case job["job_class"]
          when *ACTION_MAILER_CLASSES
            job["arguments"][0..1].join("#")
          else
            "#{job["job_class"]}#perform"
          end
        end
      end
    end
  end
end
