# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Coerces user-supplied tag hashes into a shape the OpenTelemetry SDK
    # accepts as attribute values: string keys, and values restricted to
    # the primitive types the OTLP spec allows.  Unsupported types are
    # cast to strings via `to_s`.  All string values are encoded in UTF-8.
    module Attributes
      class << self
        def format(attrs)
          attrs.each_with_object({}) do |(key, value), result|
            result[Appsignal::Utils::UTF8.encode(key.to_s)] = format_value(value)
          end
        end

        private

        def format_value(value)
          case value
          when String then Appsignal::Utils::UTF8.encode(value)
          when Integer, Float, TrueClass, FalseClass then value
          else Appsignal::Utils::UTF8.encode(value.to_s)
          end
        end
      end
    end
  end
end
