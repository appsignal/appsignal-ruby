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
        require "appsignal/integrations/rake"
        ::Rake::Task.prepend Appsignal::Integrations::RakeIntegration
      end
    end
  end
end
