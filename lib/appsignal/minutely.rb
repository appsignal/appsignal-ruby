# frozen_string_literal: true

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
        stop
        @@thread = Thread.new do
          loop do
            logger = Appsignal.logger
            logger.debug("Gathering minutely metrics with #{probes.count} probes")
            probes.each do |probe|
              begin
                name = probe.class.name
                logger.debug("Gathering minutely metrics with #{name} probe")
                probe.call
              rescue => ex
                logger.error("Error in minutely thread (#{name}): #{ex}")
              end
            end
            sleep(Appsignal::Minutely.wait_time)
          end
        end
      end

      def stop
        defined?(@@thread) && @@thread.kill
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
