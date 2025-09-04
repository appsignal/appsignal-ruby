# frozen_string_literal: true

module Appsignal
  class Hooks
    # @!visibility private
    class CodeOwnershipHook < Appsignal::Hooks::Hook
      register :code_ownership

      def dependencies_present?
        defined?(::CodeOwnership) &&
          Gem::Specification.find_by_name("code_ownership").version < Gem::Version.new("2.0") &&
          Appsignal.config && Appsignal.config[:instrument_code_ownership]
      end

      def install
        require "appsignal/integrations/code_ownership"

        Appsignal::Transaction.before_complete <<
          Appsignal::Integrations::CodeOwnershipIntegration.method(:before_complete)

        Appsignal::Environment.report_enabled("code_ownership")
      end
    end
  end
end
