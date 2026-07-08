# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Coerces user-supplied tag hashes into a shape the OpenTelemetry SDK
    # accepts as attribute values: string keys, and values restricted to
    # the primitive types the OTLP spec allows. Anything else falls back
    # to `to_s`. Shared by the metric and log backends so both behave
    # identically.
    module Attributes
      class << self
        def format(attrs)
          attrs.each_with_object({}) do |(key, value), result|
            result[key.to_s] = format_value(value)
          end
        end

        private

        def format_value(value)
          case value
          when String, Integer, Float, TrueClass, FalseClass then value
          else value.to_s
          end
        end
      end
    end
  end
end
