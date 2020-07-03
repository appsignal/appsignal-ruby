# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class ResqueHook < Appsignal::Hooks::Hook
      register :resque

      def dependencies_present?
        defined?(::Resque)
      end

      def install
        Resque::Job.class_eval do
          alias_method :perform_without_appsignal, :perform

          def perform
            transaction = Appsignal::Transaction.create(
              SecureRandom.uuid,
              Appsignal::Transaction::BACKGROUND_JOB,
              Appsignal::Transaction::GenericRequest.new({})
            )

            Appsignal.instrument "perform.resque" do
              perform_without_appsignal
            end
          rescue Exception => exception # rubocop:disable Lint/RescueException
            transaction.set_error(exception)
            raise exception
          ensure
            if transaction
              transaction.set_action_if_nil("#{payload["class"]}#perform")
              args =
                Appsignal::Utils::HashSanitizer.sanitize(
                  ResqueHelpers.arguments(payload),
                  Appsignal.config[:filter_parameters]
                )
              transaction.params = args if args
              transaction.set_tags("queue" => queue)

              Appsignal::Transaction.complete_current!
            end
            Appsignal.stop("resque")
          end
        end
      end

      class ResqueHelpers
        def self.arguments(payload)
          case payload["class"]
          when "ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper"
            nil # Set in the ActiveJob integration
          else
            payload["args"]
          end
        end
      end
    end
  end
end
