# frozen_string_literal: true

module Appsignal
  module Helpers
    module Metrics
      # Report a gauge metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash] The tags for the metric. The Hash keys can be either
      #   a String or a Symbol. The tag values can be a String, Symbol,
      #   Integer, Float, TrueClass or FalseClass.
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def set_gauge(name, value, tags = {})
        Appsignal::Extension.set_gauge(
          name.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("The gauge value '#{value}' for metric '#{name}' is too big")
      end

      # Report a counter metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash] The tags for the metric. The Hash keys can be either
      #   a String or a Symbol. The tag values can be a String, Symbol,
      #   Integer, Float, TrueClass or FalseClass.
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def increment_counter(name, value = 1.0, tags = {})
        Appsignal::Extension.increment_counter(
          name.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("The counter value '#{value}' for metric '#{name}' is too big")
      end

      # Report a distribution metric.
      #
      # @since 2.6.0
      # @param name [String, Symbol] The name of the metric.
      # @param value [Integer, Float] The value of the metric.
      # @param tags [Hash] The tags for the metric. The Hash keys can be either
      #   a String or a Symbol. The tag values can be a String, Symbol,
      #   Integer, Float, TrueClass or FalseClass.
      #
      # @see https://docs.appsignal.com/metrics/custom.html
      #   Metrics documentation
      def add_distribution_value(name, value, tags = {})
        Appsignal::Extension.add_distribution_value(
          name.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("The distribution value '#{value}' for metric '#{name}' is too big")
      end
    end
  end
end
