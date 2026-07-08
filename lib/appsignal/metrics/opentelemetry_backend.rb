# frozen_string_literal: true

require "appsignal/opentelemetry/attributes"

module Appsignal
  module Metrics
    # @!visibility private
    #
    # Routes custom metric helper calls through the OpenTelemetry metrics
    # SDK using the meter provider configured at `Appsignal.start` time when
    # collector mode is active. Mirrors the Python integration's
    # `appsignal/metrics.py`:
    #
    # - `set_gauge` uses a synchronous OTel Gauge.
    # - `increment_counter` uses an UpDownCounter so negative increments
    #   work (Counter would reject them).
    # - `add_distribution_value` uses a Histogram.
    #
    # Instruments are created once per name and cached: the OTel SDK logs a
    # "duplicate instrument registration" warning and swaps the instrument
    # if `create_*` is called again for the same name. Tags attach at record
    # time, not at instrument creation time.
    module OpenTelemetryBackend
      MUTEX = Mutex.new

      class << self
        def set_gauge(name, value, tags)
          instrument(:gauge, name).record(
            value.to_f,
            :attributes => Appsignal::OpenTelemetry::Attributes.format(tags)
          )
        end

        def increment_counter(name, value, tags)
          instrument(:up_down_counter, name).add(
            value.to_f,
            :attributes => Appsignal::OpenTelemetry::Attributes.format(tags)
          )
        end

        def add_distribution_value(name, value, tags)
          instrument(:histogram, name).record(
            value.to_f,
            :attributes => Appsignal::OpenTelemetry::Attributes.format(tags)
          )
        end

        # @!visibility private
        #
        # Test-only. Drops the cached meter and instruments so the next
        # call re-resolves `OpenTelemetry.meter_provider`.
        def reset!
          MUTEX.synchronize do
            @meter = nil
            @gauges = nil
            @counters = nil
            @histograms = nil
          end
        end

        private

        # Fetch the named instrument, creating and caching it on first use.
        # The lookup-or-create runs under the mutex so two concurrent
        # first-time calls don't both create the instrument (which would
        # make the SDK log a duplicate-registration warning).
        def instrument(kind, name)
          name = name.to_s
          MUTEX.synchronize do
            case kind
            when :gauge
              (@gauges ||= {})[name] ||= meter.create_gauge(name)
            when :up_down_counter
              (@counters ||= {})[name] ||= meter.create_up_down_counter(name)
            when :histogram
              (@histograms ||= {})[name] ||= meter.create_histogram(name)
            end
          end
        end

        # Only called from `instrument` while the mutex is held, so the plain
        # memoisation needs no extra locking of its own.
        def meter
          @meter ||= ::OpenTelemetry.meter_provider.meter("appsignal-helpers")
        end
      end
    end
  end
end
