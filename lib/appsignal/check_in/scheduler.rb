# frozen_string_literal: true

module Appsignal
  module CheckIn
    class Scheduler
      INITIAL_DEBOUNCE_SECONDS = 0.1
      BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS = 10

      def initialize
        # The mutex is used to synchronize access to the events array, the
        # waker thread and the main thread, as well as queue writes
        # (which depend on the events array) and closes (so they do not
        # happen at the same time that an event is added to the scheduler)
        @mutex = Mutex.new
        # The transmitter thread will be started when an event is first added.
        @thread = nil
        @queue = Thread::Queue.new
        # Scheduled events that have not been sent to the transmitter thread
        # yet. A copy of this array is pushed to the queue by the waker thread
        # after it has awaited the debounce period.
        @events = []
        # The waker thread is used to schedule debounces. It will be started
        # when an event is first added.
        @waker = nil
        # For internal testing purposes.
        @transmitted = 0
      end

      def schedule(event)
        unless Appsignal.active?
          Appsignal.internal_logger.debug(
            "Cannot transmit #{Event.describe([event])}: AppSignal is not active"
          )
          return
        end

        @mutex.synchronize do
          if @queue.closed?
            Appsignal.internal_logger.debug(
              "Cannot transmit #{Event.describe([event])}: AppSignal is stopped"
            )
            return
          end
          add_event(event)
          # If we're not already waiting to be awakened from a scheduled
          # debounce, schedule a short debounce, which will push the events
          # to the queue and schedule a long debounce.
          start_waker(INITIAL_DEBOUNCE_SECONDS) if @waker.nil?

          Appsignal.internal_logger.debug(
            "Scheduling #{Event.describe([event])} to be transmitted"
          )

          # Make sure to start the thread after an event has been added.
          @thread ||= Thread.new(&method(:run))
        end
      end

      def stop
        @mutex.synchronize do
          # Flush all events before closing the queue.
          push_events
        rescue ClosedQueueError
          # The queue is already closed (by a previous call to `#stop`)
          # so it is not possible to push events to it anymore.
        ensure
          # Ensure calling `#stop` closes the queue and kills
          # the waker thread, disallowing any further events from being
          # scheduled with `#schedule`.
          stop_waker
          @queue.close

          # Block until the thread has finished.
          @thread&.join
        end
      end

      # @api private
      # For internal testing purposes.
      attr_reader :thread, :waker, :queue, :events, :transmitted

      private

      def run
        loop do
          events = @queue.pop
          break if events.nil?

          transmit(events)
          @transmitted += 1
        end
      end

      def transmit(events)
        description = Event.describe(events)

        begin
          @transmitter ||= Transmitter.new(
            "#{Appsignal.config[:logging_endpoint]}/check_ins/json"
          )

          response = @transmitter.transmit(events, :format => :ndjson)

          if (200...300).include?(response.code.to_i)
            Appsignal.internal_logger.debug("Transmitted #{description}")
          else
            Appsignal.internal_logger.error(
              "Failed to transmit #{description}: #{response.code} status code"
            )
          end
        rescue => e
          Appsignal.internal_logger
            .error("Failed to transmit #{description}: #{e.class}: #{e.message}")
        end
      end

      # Must be called from within a `@mutex.synchronize` block.
      def add_event(event)
        # Remove redundant events, keeping the newly added one, which
        # should be the one with the most recent timestamp.
        @events.reject! do |existing_event|
          next unless Event.redundant?(event, existing_event)

          Appsignal.internal_logger.debug(
            "Replacing previously scheduled #{Event.describe([existing_event])}"
          )

          true
        end

        @events << event
      end

      # Must be called from within a `@mutex.synchronize` block.
      def start_waker(debounce)
        stop_waker

        @waker = Thread.new do
          sleep(debounce)

          @mutex.synchronize do
            # Make sure this waker doesn't get killed, so it can push
            # events and schedule a new waker.
            @waker = nil
            push_events
          end
        end
      end

      # Must be called from within a `@mutex.synchronize` block.
      def stop_waker
        @waker&.kill
        @waker&.join
        @waker = nil
      end

      # Must be called from within a `@mutex.synchronize` block.
      def push_events
        return if @events.empty?

        # Push a copy of the events to the queue, and clear the events array.
        # This ensures that `@events` always contains events that have not
        # yet been pushed to the queue.
        @queue.push(@events.dup)
        @events.clear

        start_waker(BETWEEN_TRANSMISSIONS_DEBOUNCE_SECONDS)
      end
    end
  end
end
