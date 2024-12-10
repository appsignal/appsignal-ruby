# frozen_string_literal: true

module Appsignal
  module CheckIn
    HEARTBEAT_CONTINUOUS_INTERVAL_SECONDS = 30
    NEW_SCHEDULER_MUTEX = Mutex.new

    class << self
      # @api private
      def continuous_heartbeats
        @continuous_heartbeats ||= []
      end

      # @api private
      def kill_continuous_heartbeats
        continuous_heartbeats.each(&:kill)
      end

      # Track cron check-ins.
      #
      # Track the execution of scheduled processes by sending a cron check-in.
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

      # Track heartbeat check-ins.
      #
      # Track the execution of long-lived processes by sending a heartbeat
      # check-in.
      #
      # @example Send a heartbeat check-in
      #   Appsignal::CheckIn.heartbeat("main_loop")
      #
      # @param identifier [String] identifier of the heartbeat check-in to report.
      # @param continuous [Boolean] whether the heartbeats should be sent continuously
      #   during the lifetime of the process. Defaults to `false`.
      # @yield the block to monitor.
      # @return [void]
      # @since 4.1.0
      # @see https://docs.appsignal.com/check-ins/heartbeat
      def heartbeat(identifier, continuous: false)
        if continuous
          continuous_heartbeats << Thread.new do
            loop do
              heartbeat(identifier)
              sleep HEARTBEAT_CONTINUOUS_INTERVAL_SECONDS
            end
          end

          return
        end

        event = Event.heartbeat(:identifier => identifier)
        scheduler.schedule(event)
      end

      # @api private
      def scheduler
        return @scheduler if @scheduler

        NEW_SCHEDULER_MUTEX.synchronize do
          @scheduler ||= Scheduler.new
        end

        @scheduler
      end

      # @api private
      def stop
        scheduler&.stop
      end
    end
  end
end

require "appsignal/check_in/event"
require "appsignal/check_in/scheduler"
require "appsignal/check_in/cron"
