# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class MriHook < Appsignal::Hooks::Hook
      register :mri

      def dependencies_present?
        defined?(::RubyVM)
      end

      def install
        Appsignal::Minutely.probes.register :mri, Appsignal::Probes::MriProbe
      end
    end
  end
end
