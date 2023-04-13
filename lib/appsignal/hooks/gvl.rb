# frozen_string_literal: true

module Appsignal
  class Hooks
    # @api private
    class GvlHook < Appsignal::Hooks::Hook
      register :gvl

      def dependencies_present?
        return false if Appsignal::System.jruby?

        require "gvltools"
        Appsignal.config && Appsignal::Probes::GvlProbe.dependencies_present?
      rescue LoadError
        false
      end

      def install
        Appsignal::Minutely.probes.register :gvl, Appsignal::Probes::GvlProbe
        ::GVLTools::GlobalTimer.enable if Appsignal.config[:enable_gvl_global_timer]
        ::GVLTools::WaitingThreads.enable if Appsignal.config[:enable_gvl_waiting_threads]
      end
    end
  end
end
