# frozen_string_literal: true

module Appsignal
  class Minutely
    class ProbeCollection
      include Appsignal::Utils::DeprecationMessage

      def initialize
        @probes = {}
      end

      # @return [Integer] Number of probes that are registered.
      def count
        probes.count
      end

      # Clears all probes from the list.
      # @return [void]
      def clear
        probes.clear
      end

      # Fetch a probe using its name.
      # @param key [Symbol/String] The name of the probe to fetch.
      # @return [Object] Returns the registered probe.
      def [](key)
        probes[key]
      end

      # @param probe [Object] Any object that listens to the `call` method will
      #   be used as a probe.
      # @deprecated Use {#register} instead.
      # @return [void]
      def <<(probe)
        deprecation_message "Deprecated `Appsignal::Minute.probes <<` " \
          "call. Please use `Appsignal::Minutely.probes.register` instead.",
          logger
        register probe.object_id, probe
      end

      # Register a new minutely probe.
      #
      # Supported probe types are:
      #
      # - Lambda - A lambda is an object that listens to a `call` method call.
      #   This `call` method is called every minute.
      # - Class instance - A class instance object is an object that listens to
      #   a `call` method call. The `call` method is called every minute.
      #
      # @example Register a new probe
      #   Appsignal::Minutely.probes.register :my_probe, lambda {}
      #
      # @example Overwrite an existing registered probe
      #   Appsignal::Minutely.probes.register :my_probe, lambda {}
      #   Appsignal::Minutely.probes.register :my_probe, lambda { puts "hello" }
      #
      # @example Add a lambda as a probe
      #   Appsignal::Minutely.probes.register :my_probe, lambda { puts "hello" }
      #   # "hello" # printed every minute
      #
      # @example Add a probe instance
      #   class MyProbe
      #     def initialize
      #       puts "started"
      #     end
      #
      #     def call
      #       puts "called"
      #     end
      #   end
      #
      #   Appsignal::Minutely.probes.register :my_probe, MyProbe.new
      #   # "started" # printed immediately
      #   # "called" # printed every minute
      #
      # @param name [Symbol/String] Name of the probe. Can be used with {[]}.
      #   This name will be used in errors in the log and allows overwriting of
      #   probes by registering new ones with the same name.
      # @param probe [Object] Any object that listens to the `call` method will
      #   be used as a probe.
      # @return [void]
      def register(name, probe)
        if probes.key?(name)
          logger.debug "A probe with the name `#{name}` is already " \
            "registered. Overwriting the entry with the new probe."
        end
        probes[name] = probe
      end

      # @api private
      def each(&block)
        probes.each(&block)
      end

      private

      attr_reader :probes

      def logger
        Appsignal.logger
      end
    end

    class << self
      # @see ProbeCollection
      # @return [ProbeCollection] Returns list of probes.
      def probes
        @@probes ||= ProbeCollection.new
      end

      # @api private
      def start
        stop
        @@thread = Thread.new do
          loop do
            logger = Appsignal.logger
            logger.debug("Gathering minutely metrics with #{probes.count} probes")
            probes.each do |name, probe|
              begin
                logger.debug("Gathering minutely metrics with '#{name}' probe")
                probe.call
              rescue => ex
                logger.error("Error in minutely probe '#{name}': #{ex}")
              end
            end
            sleep(Appsignal::Minutely.wait_time)
          end
        end
      end

      # @api private
      def stop
        defined?(@@thread) && @@thread.kill
      end

      # @api private
      def wait_time
        60 - Time.now.sec
      end

      # @api private
      def register_garbage_collection_probe
        probes.register :garbage_collection, GCProbe.new
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
