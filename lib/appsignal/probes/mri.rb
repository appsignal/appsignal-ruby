# frozen_string_literal: true

module Appsignal
  module Probes
    class MriProbe
      include Helpers

      # @api private
      def self.dependencies_present?
        defined?(::RubyVM) && ::RubyVM.respond_to?(:stat)
      end

      def initialize(appsignal: Appsignal, gc_profiler: Appsignal::GarbageCollection.profiler)
        Appsignal.logger.debug("Initializing VM probe")
        @appsignal = appsignal
        @gc_profiler = gc_profiler
      end

      # @api private
      def call
        stat = RubyVM.stat

        constant_cache_invalidations = stat[:constant_cache_invalidations]
        if constant_cache_invalidations
          set_gauge_with_hostname(
            "ruby_vm",
            constant_cache_invalidations,
            :metric => :constant_cache_invalidations
          )
        end

        constant_cache_misses = stat[:constant_cache_misses]
        if constant_cache_misses
          set_gauge_with_hostname(
            "ruby_vm",
            constant_cache_misses,
            :metric => :constant_cache_misses
          )
        end

        class_serial = stat[:class_serial]
        set_gauge_with_hostname("ruby_vm", class_serial, :metric => :class_serial) if class_serial

        global_constant_state =
          stat[:constant_cache] ? stat[:constant_cache].values.sum : stat[:global_constant_state]
        if global_constant_state
          set_gauge_with_hostname(
            "ruby_vm",
            global_constant_state,
            :metric => :global_constant_state
          )
        end

        set_gauge_with_hostname("thread_count", Thread.list.size)
        if Appsignal::GarbageCollection.enabled?
          gauge_delta(:gc_time, @gc_profiler.total_time) do |gc_time|
            set_gauge_with_hostname("gc_time", gc_time) if gc_time > 0
          end
        end

        gc_stats = GC.stat
        gauge_delta(
          :allocated_objects,
          gc_stats[:total_allocated_objects] || gc_stats[:total_allocated_object]
        ) do |allocated_objects|
          set_gauge_with_hostname("allocated_objects", allocated_objects)
        end

        gauge_delta(:gc_count, GC.count) do |gc_count|
          set_gauge_with_hostname("gc_count", gc_count, :metric => :gc_count)
        end
        gauge_delta(:minor_gc_count, gc_stats[:minor_gc_count]) do |minor_gc_count|
          set_gauge_with_hostname("gc_count", minor_gc_count, :metric => :minor_gc_count)
        end
        gauge_delta(:major_gc_count, gc_stats[:major_gc_count]) do |major_gc_count|
          set_gauge_with_hostname("gc_count", major_gc_count, :metric => :major_gc_count)
        end

        set_gauge_with_hostname("heap_slots",
          gc_stats[:heap_live_slots] || gc_stats[:heap_live_slot], :metric => :heap_live)
        set_gauge_with_hostname("heap_slots",
          gc_stats[:heap_free_slots] || gc_stats[:heap_free_slot], :metric => :heap_free)
      end
    end
  end
end
