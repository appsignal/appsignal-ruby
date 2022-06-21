module Appsignal
  module Probes
    class MriProbe
      # @api private
      def self.dependencies_present?
        defined?(::RubyVM) && ::RubyVM.respond_to?(:stat)
      end

      def initialize
        Appsignal.logger.debug("Initializing VM probe")
      end

      # @api private
      def call
        stat = RubyVM.stat
        [:class_serial, :global_constant_state].each do |metric|
          Appsignal.add_distribution_value(
            "ruby_vm",
            stat[metric],
            :metric => metric
          )
        end

        Appsignal.set_gauge("thread_count", Thread.list.size)
      end
    end
  end
end
