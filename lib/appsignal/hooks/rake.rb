# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class RakeHook < Appsignal::Hooks::Hook
      register :rake

      def dependencies_present?
        defined?(::Rake::Task)
      end

      def install
        ::Rake::Task.class_eval do
          alias :execute_without_appsignal :execute

          def execute(*args)
            execute_without_appsignal(*args)
          rescue Exception => error # rubocop:disable Lint/RescueException
            # Format given arguments and cast to hash if possible
            params, _ = args
            params = params.to_hash if params.respond_to?(:to_hash)

            transaction = Appsignal::Transaction.create(
              SecureRandom.uuid,
              Appsignal::Transaction::BACKGROUND_JOB,
              Appsignal::Transaction::GenericRequest.new(
                :params => params
              )
            )
            transaction.set_action(name)
            transaction.set_error(error)
            transaction.complete
            Appsignal.stop("rake")
            raise error
          end
        end
      end
    end
  end
end
