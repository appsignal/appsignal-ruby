module Appsignal
  module Probes
    module Helpers
      private

      def gauge_delta_cache
        @gauge_delta_cache ||= {}
      end

      # Calculate the delta of two values for a gauge metric
      #
      # First call will store the data for the metric in the cache and the
      # second call will return the delta of the gauge metric. This is used for
      # absolute counter values which we want to track as gauges.
      #
      # @example
      #   gauge_delta :my_cache_key, 10
      #   gauge_delta :my_cache_key, 15
      #   # Returns a value of `5`
      def gauge_delta(cache_key, value)
        previous_value = gauge_delta_cache[cache_key]
        gauge_delta_cache[cache_key] = value
        return unless previous_value

        value - previous_value
      end
    end
  end
end
