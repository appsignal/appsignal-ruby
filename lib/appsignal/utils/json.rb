# frozen_string_literal: true

module Appsignal
  module Utils
    class JSON
      MAX_DEPTH = 100
      MAX_DEPTH_PLACEHOLDER = "[MAX DEPTH REACHED]"
      UNSERIALIZABLE_PLACEHOLDER = "[UNSERIALIZABLE VALUE]"

      class << self
        def generate(body)
          ::JSON.generate(jsonify(body, 0))
        end

        private

        def jsonify(value, depth)
          case value
          when String
            encode_utf8(value)
          when Float
            jsonify_float(value)
          when Numeric, NilClass, TrueClass, FalseClass
            value
          when Hash
            return max_depth_placeholder if depth >= MAX_DEPTH

            value.each_with_object({}) do |(k, v), hash|
              hash[jsonify(k, depth + 1)] = jsonify(v, depth + 1)
            end
          when Array
            return max_depth_placeholder if depth >= MAX_DEPTH

            value.map { |v| jsonify(v, depth + 1) }
          else
            jsonify(object_to_s(value), depth)
          end
        end

        def object_to_s(value)
          value.to_s
        rescue => e
          Appsignal.internal_logger.error(
            "Unable to serialize value: #<#{value.class}: to_s raised #{e.class}: #{e.message}>"
          )
          UNSERIALIZABLE_PLACEHOLDER
        end

        def max_depth_placeholder
          Appsignal.internal_logger.error(
            "Data is nested more than #{MAX_DEPTH} levels deep. " \
              "Deeper values are replaced with '#{MAX_DEPTH_PLACEHOLDER}'."
          )
          MAX_DEPTH_PLACEHOLDER
        end

        def jsonify_float(value)
          if value.nan?
            "NaN"
          elsif value.infinite?
            value.positive? ? "Infinity" : "-Infinity"
          else
            value
          end
        end

        def encode_utf8(value)
          if value.encoding == Encoding::BINARY
            String.new(value, :encoding => Encoding::UTF_8).scrub
          else
            value.encode(
              "utf-8",
              :invalid => :replace,
              :undef   => :replace
            )
          end
        end
      end
    end
  end
end
