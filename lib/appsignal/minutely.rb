module Appsignal
  # @api private
  class Minutely
    class << self
      # List of probes. Probes can be lamdba's or objects that
      # respond to call.
      def probes
        @@probes ||= []
      end

      def start
        Thread.new do
          begin
            loop do
              Appsignal.logger.debug("Gathering minutely metrics with #{probes.count} probe(s)")
              probes.each(&:call)
              sleep(wait_time)
            end
          rescue Exception => ex
            Appsignal.logger.error("Error in minutely thread: #{ex}")
          end
        end
      end

      def wait_time
        60 - Time.now.sec
      end

      def add_gc_probe
        probes << GCProbe.new
      end
    end

    class GCProbe
      def call
        GC.stat.each do |key, value|
          Appsignal.set_process_gauge("gc.#{key}", value)
        end
      end
    end
  end
end
