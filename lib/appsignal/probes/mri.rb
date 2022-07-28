module Appsignal
  module Probes
    class MriProbe
      include Helpers

      # @api private
      def self.dependencies_present?
        defined?(::RubyVM) && ::RubyVM.respond_to?(:stat)
      end

      def self.garbage_collection_profiler
        @garbage_collection_profiler ||= Appsignal::GarbageCollectionProfiler.new
      end

      def initialize(appsignal = Appsignal)
        Appsignal.logger.debug("Initializing VM probe")
        @appsignal = appsignal
      end

      # @api private
      def call
        stat = RubyVM.stat

        set_gauge(
          "ruby_vm",
          stat[:class_serial],
          :metric => :class_serial
        )

        set_gauge(
          "ruby_vm",
          stat[:constant_cache] ? stat[:constant_cache].values.sum : stat[:global_constant_state],
          :metric => :global_constant_state
        )

        set_gauge("thread_count", Thread.list.size)
        set_gauge("gc_total_time", MriProbe.garbage_collection_profiler.total_time)

        gc_stats = GC.stat
        allocated_objects =
          gauge_delta(
            :allocated_objects,
            gc_stats[:total_allocated_objects] || gc_stats[:total_allocated_object]
          )
        set_gauge("allocated_objects", allocated_objects) if allocated_objects

        gc_count = gauge_delta(:gc_count, GC.count)
        set_gauge("gc_count", gc_count, :metric => :gc_count) if gc_count
        minor_gc_count = gauge_delta(:minor_gc_count, gc_stats[:minor_gc_count])
        if minor_gc_count
          set_gauge("gc_count", minor_gc_count, :metric => :minor_gc_count)
        end
        major_gc_count = gauge_delta(:major_gc_count, gc_stats[:major_gc_count])
        if major_gc_count
          set_gauge("gc_count", major_gc_count, :metric => :major_gc_count)
        end

        set_gauge("heap_slots", gc_stats[:heap_live_slots] || gc_stats[:heap_live_slot], :metric => :heap_live)
        set_gauge("heap_slots", gc_stats[:heap_free_slots] || gc_stats[:heap_free_slot], :metric => :heap_free)
      end

      private

      def set_gauge(metric, value, tags = {})
        @appsignal.set_gauge(metric, value, tags)
      end
    end
  end
end
