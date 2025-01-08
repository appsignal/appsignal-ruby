# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class OwnershipHook < Appsignal::Hooks::Hook
      register :ownership

      def dependencies_present?
        defined?(::Ownership) &&
          Gem::Version.new(::Ownership::VERSION) >= Gem::Version.new("0.2.0") &&
          Appsignal.config &&
          Appsignal.config[:instrument_ownership]
      end

      def install
        require "appsignal/integrations/ownership"

        # If a transaction is created in a code context that has an owner,
        # set the namespace of the transaction to the owner.
        Appsignal::Transaction.after_create <<
          Appsignal::Integrations::OwnershipIntegrationHelper.method(:after_create)

        # If an error was reported in a code context that has an owner,
        # set the namespace of the transaction to the owner.
        # In some circumstances, this will be more accurate than the last owner
        # that was set for the transaction, which is what would otherwise be
        # reported.
        Appsignal::Transaction.before_complete <<
          Appsignal::Integrations::OwnershipIntegrationHelper.method(:before_complete)

        # If an owner is set in a code context that has an active transaction,
        # set the namespace of the transaction to the owner.
        unless ::Ownership.singleton_class.included_modules.include?(
          Appsignal::Integrations::OwnershipIntegration
        )
          ::Ownership.singleton_class.prepend Appsignal::Integrations::OwnershipIntegration
        end

        Appsignal::Environment.report_enabled("ownership")
      end
    end
  end
end
