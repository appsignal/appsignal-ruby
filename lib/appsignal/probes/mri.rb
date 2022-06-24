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
        [:class_serial, :global_constant_state].each do |metric|
          @appsignal.add_distribution_value(
            "ruby_vm",
            stat[metric],
            :metric => metric
          )
        end

        @appsignal.set_gauge("thread_count", Thread.list.size)
        @appsignal.set_gauge("gc_total_time", MriProbe.garbage_collection_profiler.total_time)

        gc_stats = GC.stat
        @appsignal.set_gauge("total_allocated_objects", gc_stats[:total_allocated_objects])

        @appsignal.add_distribution_value("gc_count", GC.count, :metric => :gc_count)
        @appsignal.add_distribution_value("gc_count", gc_stats[:minor_gc_count], :metric => :minor_gc_count)
        @appsignal.add_distribution_value("gc_count", gc_stats[:major_gc_count], :metric => :major_gc_count)

        @appsignal.add_distribution_value("heap_slots", gc_stats[:heap_live_slots], :metric => :heap_live)
        @appsignal.add_distribution_value("heap_slots", gc_stats[:heap_free_slots], :metric => :heap_free)
      end
    end
  end
end
