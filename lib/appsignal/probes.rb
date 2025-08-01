# frozen_string_literal: true

module Appsignal
  module Probes
    # @return [Integer]
    # @!visibility private
    ITERATION_IN_SECONDS = 60

    # @!visibility private
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
      # @param key [Symbol, String] The name of the probe to fetch.
      # @return [Object] Returns the registered probe.
      def [](key)
        probes[key]
      end

      def internal_register(name, probe)
        if probes.key?(name)
          logger.debug "A probe with the name `#{name}` is already " \
            "registered. Overwriting the entry with the new probe."
        end
        probes[name] = probe
      end

      def unregister(name)
        probes.delete(name)
      end

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
      # @!visibility private
      def mutex
        @mutex ||= Thread::Mutex.new
      end

      # @see ProbeCollection
      # @return [ProbeCollection] Returns list of probes.
      # @!visibility private
      def probes
        @probes ||= ProbeCollection.new
      end

      # Register a new minutely probe.
      #
      # Supported probe types are:
      #
      # - Lambda - A lambda is an object that listens to a `call` method call.
      #   This `call` method is called every minute.
      # - Class - A class object is an object that listens to a `new` and
      #   `call` method call. The `new` method is called when the minutely
      #   probe thread is started to initialize all probes. This allows probes
      #   to load dependencies once beforehand. Their `call` method is called
      #   every minute.
      # - Class instance - A class instance object is an object that listens to
      #   a `call` method call. The `call` method is called every minute.
      #
      # @example Register a new probe
      #   Appsignal::Probes.register :my_probe, lambda {}
      #
      # @example Overwrite an existing registered probe
      #   Appsignal::Probes.register :my_probe, lambda {}
      #   Appsignal::Probes.register :my_probe, lambda { puts "hello" }
      #
      # @example Add a lambda as a probe
      #   Appsignal::Probes.register :my_probe, lambda { puts "hello" }
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
      #   Appsignal::Probes.register :my_probe, MyProbe.new
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
      #   Appsignal::Probes.register :my_probe, MyProbe
      #   Appsignal::Probes.start # This is called for you
      #   # "started" # Printed on Appsignal::Probes.start
      #   # "called" # Repeated every minute
      #
      # @param name [Symbol, String] Name of the probe. Can be used with
      #   {ProbeCollection#[]}. This name will be used in errors in the log and
      #   allows overwriting of probes by registering new ones with the same
      #   name.
      # @param probe [Object] Any object that listens to the `call` method will
      #   be used as a probe.
      # @return [void]
      def register(name, probe)
        probes.internal_register(name, probe)

        initialize_probe(name, probe) if started?
      end

      # Unregister a probe that's registered with {register}.
      # Can also be used to unregister automatically registered probes by the
      # gem.
      #
      # @example Unregister probes
      #   # First register a probe
      #   Appsignal::Probes.register :my_probe, lambda {}
      #
      #   # Then unregister a probe if needed
      #   Appsignal::Probes.unregister :my_probe
      #
      # @param name [Symbol, String] Name of the probe used to {register} the
      #   probe.
      # @return [void]
      def unregister(name)
        probes.unregister(name)

        uninitialize_probe(name)
      end

      # @return [void]
      # @api private
      def start
        stop
        @started = true
        @thread = Thread.new do
          # Advise multi-threaded app servers to ignore this thread
          # for the purposes of fork safety warnings
          if Thread.current.respond_to?(:thread_variable_set)
            Thread.current.thread_variable_set(:fork_safe, true)
          end

          sleep initial_wait_time
          initialize_probes
          loop do
            start_time = Time.now
            logger = Appsignal.internal_logger
            mutex.synchronize do
              logger.debug("Gathering minutely metrics with #{probe_instances.count} probes")
              probe_instances.each do |name, probe|
                logger.debug("Gathering minutely metrics with '#{name}' probe")
                probe.call
              rescue => ex
                logger.error(
                  "Error in minutely probe '#{name}': #{ex.class}: #{ex.message}\n" \
                    "#{ex.backtrace.join("\n")}"
                )
              end
            end
            end_time = Time.now
            duration = end_time - start_time
            if duration >= ITERATION_IN_SECONDS
              logger.error(
                "The minutely probes took more than 60 seconds. " \
                  "The probes should not take this long as metrics will not " \
                  "be accurately reported."
              )
            end
            sleep wait_time
          end
        end
      end

      # Returns if the probes thread has been started. If the value is false or
      # nil, it has not been started yet.
      #
      # @return [Boolean, nil]
      def started?
        @started
      end

      # Stop the minutely probes mechanism. Stop the thread and clear all probe
      # instances.
      #
      # @return [void]
      def stop
        defined?(@thread) && @thread.kill
        @started = false
        probe_instances.clear
      end

      # @!visibility private
      def wait_time
        ITERATION_IN_SECONDS - Time.now.sec
      end

      private

      def initial_wait_time
        remaining_seconds = ITERATION_IN_SECONDS - Time.now.sec
        return remaining_seconds if remaining_seconds > 30

        remaining_seconds + ITERATION_IN_SECONDS
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
        mutex.synchronize do
          probe_instances[name] = instance
        end
      rescue => error
        logger = Appsignal.internal_logger
        logger.error(
          "Error while initializing minutely probe '#{name}': #{error.class}: #{error.message}\n" \
            "#{error.backtrace.join("\n")}"
        )
      end

      def uninitialize_probe(name)
        mutex.synchronize do
          probe_instances.delete(name)
        end
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

require "appsignal/probes/helpers"
require "appsignal/probes/gvl"
require "appsignal/probes/mri"
require "appsignal/probes/sidekiq"
