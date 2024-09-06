# frozen_string_literal: true

module Appsignal
  module CheckIn
    class << self
      # Track cron check-ins.
      #
      # Track the execution of certain processes by sending a cron check-in.
      #
      # To track the duration of a piece of code, pass a block to {.cron}
      # to report both when the process starts, and when it finishes.
      #
      # If an exception is raised within the block, the finish event will not
      # be reported, triggering a notification about the missing cron check-in.
      # The exception will bubble outside of the cron check-in block.
      #
      # @example Send a cron check-in
      #   Appsignal::CheckIn.cron("send_invoices")
      #
      # @example Send a cron check-in with duration
      #   Appsignal::CheckIn.cron("send_invoices") do
      #     # your code
      #   end
      #
      # @param identifier [String] identifier of the cron check-in to report.
      # @yield the block to monitor.
      # @return [void]
      # @since 3.13.0
      # @see https://docs.appsignal.com/check-ins/cron
      def cron(identifier)
        cron = Appsignal::CheckIn::Cron.new(:identifier => identifier)
        output = nil

        if block_given?
          cron.start
          output = yield
        end

        cron.finish
        output
      end

      # @api private
      def transmitter
        @transmitter ||= Transmitter.new(
          "#{Appsignal.config[:logging_endpoint]}/check_ins/json"
        )
      end

      # @api private
      def scheduler
        @scheduler ||= Scheduler.new
      end

      # @api private
      def stop
        scheduler&.stop
      end
    end
  end
end

require "appsignal/check_in/scheduler"
require "appsignal/check_in/cron"
