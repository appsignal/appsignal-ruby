# frozen_string_literal: true

module Appsignal
  module Integrations
    # @api private
    module OwnershipIntegration
      # Implement the `around_change` logic by monkey-patching the reader,
      # instead of by using the `around_change=` writer. This allows customers
      # to use the `around_change=` writer in their own code without
      # accidentally overriding AppSignal's instrumentation.
      def around_change
        proc do |owner, block|
          OwnershipIntegrationHelper.set(Appsignal::Transaction.current, owner)

          original = super

          if original
            original.call(owner, block)
          else
            block.call
          end
        end
      end
    end

    module OwnershipIntegrationHelper
      class << self
        def set(transaction, owner)
          return if owner.nil?

          transaction.add_tags(:owner => owner)
          transaction.set_namespace(owner) if set_namespace?
        end

        def after_create(transaction)
          set(transaction, ::Ownership.owner)
        end

        def before_complete(transaction, error)
          set(transaction, error.owner) if error.respond_to?(:owner)
        end

        private

        def set_namespace?
          Appsignal.config && Appsignal.config[:ownership_set_namespace]
        end
      end
    end
  end
end
