# frozen_string_literal: true

module Appsignal
  module Probes
    module Helpers
      private

      def gauge_delta_cache
        @gauge_delta_cache ||= {}
      end

      # Calculate the delta of two values for a gauge metric.
      #
      # When this method is called, the given value is stored in a cache
      # under the given cache key.
      #
      # A block must be passed to this method. The first time the method
      # is called for a given cache key, the block will not be yielded to.
      # In subsequent calls, the delta between the previously stored value
      # in the cache for that key and the value given in this invocation
      # will be yielded to the block.
      #
      # This is used for absolute counter values which we want to track as
      # gauges.
      #
      # @example
      #   gauge_delta :with_block, 10 do |delta|
      #     puts "this block will not be yielded to"
      #   end
      #   gauge_delta :with_block, 15 do |delta|
      #     # `delta` has a value of `5`
      #     puts "this block will be yielded to with delta = #{delta}"
      #   end
      #
      def gauge_delta(cache_key, value)
        previous_value = gauge_delta_cache[cache_key]
        gauge_delta_cache[cache_key] = value
        return unless previous_value

        yield value - previous_value
      end

      def hostname
        return @hostname if defined?(@hostname)

        config = @appsignal.config
        # Auto detect hostname as fallback. May be inaccurate.
        @hostname =
          config[:hostname] || Socket.gethostname
        Appsignal.internal_logger.debug "Probe helper: Using hostname config " \
          "option '#{@hostname.inspect}' as hostname"

        @hostname
      end

      def set_gauge_with_hostname(metric, value, tags = {})
        @appsignal.set_gauge(metric, value, { :hostname => hostname }.merge(tags))
      end
    end
  end
end
