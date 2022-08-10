# frozen_string_literal: true

module Appsignal
  # @api private
  module GarbageCollection
    # Return the GC profiler wrapper.
    #
    # Returns {Profiler} if the Ruby Garbage Collection profiler is enabled.
    # This is checked by calling `GC::Profiler.enabled?`.
    #
    # GC profiling is disabled by default due to the overhead it causes. Do not
    # enable this in production for long periods of time.
    def self.profiler
      # Cached instances so it doesn't create a new object every time this
      # method is called. Especially necessary for the {Profiler} because a new
      # instance will have a new internal time counter.
      @real_profiler ||= Profiler.new
      @nil_profiler ||= NilProfiler.new

      enabled? ? @real_profiler : @nil_profiler
    end

    # Check if Garbage Collection is enabled at the moment.
    #
    # @return [Boolean]
    def self.enabled?
      GC::Profiler.enabled?
    end

    # Unset the currently cached profilers.
    #
    # @return [void]
    def self.clear_profiler!
      @real_profiler = nil
      @nil_profiler = nil
    end

    # A wrapper around Ruby's `GC::Profiler` that tracks garbage collection
    # time, while clearing `GC::Profiler`'s total_time to make sure it doesn't
    # leak memory by keeping garbage collection run samples in memory.
    class Profiler
      def self.lock
        @lock ||= Mutex.new
      end

      def initialize
        @total_time = 0
      end

      # Whenever {#total_time} is called, the current `GC::Profiler#total_time`
      # gets added to `@total_time`, after which `GC::Profiler.clear` is called
      # to prevent it from leaking memory. A class-level lock is used to make
      # sure garbage collection time is never counted more than once.
      #
      # Whenever `@total_time` gets above two billion milliseconds (about 23
      # days), it's reset to make sure the result fits in a signed 32-bit
      # integer.
      #
      # @return [Integer]
      def total_time
        lock.synchronize do
          @total_time += (internal_profiler.total_time * 1000).round
          internal_profiler.clear
        end

        @total_time = 0 if @total_time > 2_000_000_000

        @total_time
      end

      private

      def internal_profiler
        GC::Profiler
      end

      def lock
        self.class.lock
      end
    end

    # A dummy profiler that always returns 0 as the total time. Used when GC
    # profiler is disabled.
    class NilProfiler
      def total_time
        0
      end
    end
  end
end
