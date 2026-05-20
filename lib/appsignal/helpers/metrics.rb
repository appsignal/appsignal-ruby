# frozen_string_literal: true

module Appsignal
  module Helpers
    module Metrics
      # Report a gauge metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash<String, Object>] The tags for the metric. The Hash
      #   keys can be either a String or a Symbol. The tag values can be a
      #   String, Symbol, Integer, Float, TrueClass or FalseClass.
      # @return [void]
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def set_gauge(name, value, tags = {})
        Appsignal::Metrics.backend.set_gauge(name, value, tags)
      end

      # Report a counter metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash<String, Object>] The tags for the metric. The Hash
      #   keys can be either a String or a Symbol. The tag values can be a
      #   String, Symbol, Integer, Float, TrueClass or FalseClass.
      # @return [void]
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def increment_counter(name, value = 1.0, tags = {})
        Appsignal::Metrics.backend.increment_counter(name, value, tags)
      end

      # Report a distribution metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash<String, Object>] The tags for the metric. The Hash
      #   keys can be either a String or a Symbol. The tag values can be a
      #   String, Symbol, Integer, Float, TrueClass or FalseClass.
      # @return [void]
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def add_distribution_value(name, value, tags = {})
        Appsignal::Metrics.backend.add_distribution_value(name, value, tags)
      end
    end
  end
end
