# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module ResquePlugin
      def self.extended(_)
        callers = caller
        Appsignal::Utils::DeprecationMessage.message \
          "The AppSignal ResquePlugin is deprecated and does " \
          "nothing on extend. In this version of the AppSignal Ruby gem " \
          "the integration with Resque is automatic on all Resque workers. " \
          "Please remove the following line from this file to remove this " \
          "message: extend Appsignal::Integrations::ResquePlugin\n" \
          "#{callers.first}"
      end
    end
  end
end

module Appsignal
  module Integrations
    # @api private
    module ResqueIntegration
      def perform
        transaction = Appsignal::Transaction.create(
          SecureRandom.uuid,
          Appsignal::Transaction::BACKGROUND_JOB,
          Appsignal::Transaction::GenericRequest.new({})
        )

        Appsignal.instrument "perform.resque" do
          super
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
