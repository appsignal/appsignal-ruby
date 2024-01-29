# frozen_string_literal: true

module Appsignal
  class Minutely
    class ProbeCollection
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

      # Register a new minutely probe.
      #
      # Supported probe types are:
      #
      # - Lambda - A lambda is an object that listens to a `call` method call.
      #   This `call` method is called every minute.
      # - Class - A class object is an object that listens to a `new` and
      #   `call` method call. The `new` method is called when the Minutely
      #   probe thread is started to initialize all probes. This allows probes
      #   to load dependencies once beforehand. Their `call` method is called
      #   every minute.
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
      # @example Add a probe class
      #   class MyProbe
      #     def initialize
      #       # Add things that only need to be done on start up for this probe
      #       require "some/library/dependency"
      #       @cache = {} # initialize a local cache variable
      #       puts "started"
      #     end
      #
      #     def call
      #       puts "called"
      #     end
      #   end
      #
      #   Appsignal::Minutely.probes.register :my_probe, MyProbe
      #   Appsignal::Minutely.start # This is called for you
      #   # "started" # Printed on Appsignal::Minutely.start
      #   # "called" # Repeated every minute
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
        Appsignal.internal_logger
      end
    end

    class << self
      # @see ProbeCollection
      # @return [ProbeCollection] Returns list of probes.
      def probes
        @probes ||= ProbeCollection.new
      end

      # @api private
      def start
        stop
        @thread = Thread.new do
          # Advise multi-threaded app servers to ignore this thread
          # for the purposes of fork safety warnings
          if Thread.current.respond_to?(:thread_variable_set)
            Thread.current.thread_variable_set(:fork_safe, true)
          end

          sleep initial_wait_time
          initialize_probes
          loop do
            logger = Appsignal.internal_logger
            logger.debug("Gathering minutely metrics with #{probe_instances.count} probes")
            probe_instances.each do |name, probe|
              logger.debug("Gathering minutely metrics with '#{name}' probe")
              probe.call
            rescue => ex
              logger.error "Error in minutely probe '#{name}': #{ex}"
              logger.debug ex.backtrace.join("\n")
            end
            sleep wait_time
          end
        end
      end

      # @api private
      def stop
        defined?(@thread) && @thread.kill
        probe_instances.clear
      end

      # @api private
      def wait_time
        60 - Time.now.sec
      end

      private

      def initial_wait_time
        remaining_seconds = 60 - Time.now.sec
        return remaining_seconds if remaining_seconds > 30

        remaining_seconds + 60
      end

      def initialize_probes
        probes.each do |name, probe|
          initialize_probe(name, probe)
        end
      end

      def initialize_probe(name, probe)
        if probe.respond_to? :new
          instance = probe.new
          klass = probe
        else
          instance = probe
          klass = instance.class
        end
        unless dependencies_present?(klass)
          Appsignal.internal_logger.debug "Skipping '#{name}' probe, " \
            "#{klass}.dependency_present? returned falsy"
          return
        end
        probe_instances[name] = instance
      rescue => error
        logger = Appsignal.internal_logger
        logger.error "Error while initializing minutely probe '#{name}': #{error}"
        logger.debug error.backtrace.join("\n")
      end

      def dependencies_present?(probe)
        return true unless probe.respond_to? :dependencies_present?

        probe.dependencies_present?
      end

      def probe_instances
        @probe_instances ||= {}
      end
    end
  end
end
