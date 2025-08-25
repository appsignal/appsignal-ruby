# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module CodeOwnershipIntegration
      class << self
        def before_complete(transaction, error)
          team = nil
          begin
            team = ::CodeOwnership.for_backtrace(error.backtrace)
          rescue => ex
            logger = Appsignal.internal_logger
            logger.error(
              "Error while looking up CodeOwnership team: #{ex.class}: #{ex.message}\n" \
                "#{ex.backtrace.join("\n")}"
            )
          end

          return if team.nil?

          transaction.add_tags(:owner => team.name)
        end
      end
    end
  end
end
