# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module CodeOwnershipIntegration
      class << self
        def before_complete(transaction, error)
          return unless error

          team = ::CodeOwnership.for_backtrace(error.backtrace)
          team ||= team_for_backtrace_locations(error)
          transaction.add_tags(:owner => team.name) if team
        rescue => ex
          logger = Appsignal.internal_logger
          logger.error(
            "Error while looking up CodeOwnership team: #{ex.class}: #{ex.message}\n" \
              "#{ex.backtrace.join("\n")}"
          )
        end

        private

        def team_for_backtrace_locations(error)
          return unless error.respond_to?(:backtrace_locations)

          locations = error.backtrace_locations
          return unless locations

          locations.each do |location|
            path = location.absolute_path || location.path
            next unless path

            if path.start_with?("#{Dir.pwd}/")
              path = path[(Dir.pwd.length + 1)..-1]
            end

            team = ::CodeOwnership.for_file(path)
            return team if team
          end

          nil
        end
      end
    end
  end
end
