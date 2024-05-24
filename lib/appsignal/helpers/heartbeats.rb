# frozen_string_literal: true

module Appsignal
  module Helpers
    module Heartbeats
      # Track heartbeats
      #
      # Track the execution of certain processes by sending a hearbeat.
      #
      # To track the duration of a piece of code, pass a block to {.heartbeat}
      # to report both when the process starts, and when it finishes.
      #
      # If an exception is raised within the block, the finish event will not
      # be reported, triggering a notification about the missing heartbeat. The
      # exception will bubble outside of the heartbeat block.
      #
      # @example Send a heartbeat
      #   Appsignal.heartbeat("send_invoices")
      #
      # @example Send a heartbeat with duration
      #   Appsignal.heartbeat("send_invoices") do
      #     # your code
      #   end
      #
      # @param name [String] name of the heartbeat to report.
      # @yield the block to monitor.
      # @return [void]
      # @since 3.7.0
      # @see https://docs.appsignal.com/heartbeats
      def heartbeat(name)
        heartbeat = Appsignal::Heartbeat.new(:name => name)
        output = nil

        if block_given?
          heartbeat.start
          output = yield
        end

        heartbeat.finish
        output
      end
    end
  end
end
