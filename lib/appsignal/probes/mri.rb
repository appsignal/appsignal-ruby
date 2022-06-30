module Appsignal
  module Probes
    class MriProbe
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

        @appsignal.add_distribution_value(
          "ruby_vm",
          stat[:class_serial],
          :metric => :class_serial
        )

        @appsignal.add_distribution_value(
          "ruby_vm",
          stat[:constant_cache] ? stat[:constant_cache].values.sum : stat[:global_constant_state],
          :metric => :global_constant_state
        )

        @appsignal.set_gauge("thread_count", Thread.list.size)
        @appsignal.set_gauge("gc_total_time", MriProbe.garbage_collection_profiler.total_time)

        gc_stats = GC.stat
        @appsignal.set_gauge("total_allocated_objects", gc_stats[:total_allocated_objects] || gc_stats[:total_allocated_object])

        @appsignal.add_distribution_value("gc_count", GC.count, :metric => :gc_count)
        @appsignal.add_distribution_value("gc_count", gc_stats[:minor_gc_count], :metric => :minor_gc_count)
        @appsignal.add_distribution_value("gc_count", gc_stats[:major_gc_count], :metric => :major_gc_count)

        @appsignal.add_distribution_value("heap_slots", gc_stats[:heap_live_slots] || gc_stats[:heap_live_slot], :metric => :heap_live)
        @appsignal.add_distribution_value("heap_slots", gc_stats[:heap_free_slots] || gc_stats[:heap_free_slot], :metric => :heap_free)
      end
    end
  end
end
