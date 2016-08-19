module Appsignal
  # Appsignal::GarbageCollectionProfiler wraps Ruby's GC::Profiler to be able
  # to track garbage collection time for multiple transactions, while
  # constantly clearing GC::Profiler's total_time to make sure it doesn't leak
  # memory by keeping garbage collection run samples in memory.

  class GarbageCollectionProfiler
    def initialize
      @total_time = 0
    end

    # Whenever #total_time is called, the current GC::Profiler.total_time gets
    # added to @total_time, after which GC::Profiler.clear is called to prevent
    # it from leaking memory. A class-level lock is used to make sure garbage
    # collection time is never counted more than once.
    #
    # Whenever @total_time gets above two billion milliseconds (about 23 days),
    # it's reset to make sure the result fits in a signed 32-bit integer.

    def total_time
      lock.synchronize do
        @total_time += (internal_profiler.total_time * 1000).round
        internal_profiler.clear
      end

      if @total_time > 2_000_000_000
        @total_time = 0
      end

      @total_time
    end

    private

    def self.lock
      @lock ||= Mutex.new
    end

    def internal_profiler
      GC::Profiler
    end

    def lock
      self.class.lock
    end
  end
end
