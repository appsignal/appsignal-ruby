module Appsignal
  module Probes
    class MriProbe
      # @api private
      def self.dependencies_present?
        defined?(::RubyVM) && ::RubyVM.respond_to?(:stat)
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
        @appsignal.set_gauge("gc_runs", GC.count)

        gc_stats = GC.stat

        {
          :total_allocated_objects => gc_stats[:total_allocated_objects],
          :major_gc_count => gc_stats[:major_gc_count],
          :minor_gc_count => gc_stats[:minor_gc_count],
          :heap_live => gc_stats[:heap_live_slots],
          :heap_free => gc_stats[:heap_free_slots]
        }.each do |metric, value|
          @appsignal.add_distribution_value("gc_stats", value, :metric => metric)
        end
      end
    end
  end
end
