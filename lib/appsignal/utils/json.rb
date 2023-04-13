# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    class JSON
      class << self
        def generate(body)
          ::JSON.generate(jsonify(body))
        end

        private

        def jsonify(value)
          case value
          when String
            encode_utf8(value)
          when Numeric, NilClass, TrueClass, FalseClass
            value
          when Hash
            value.each_with_object({}) do |(k, v), hash|
              hash[jsonify(k)] = jsonify(v)
            end
          when Array
            value.map { |v| jsonify(v) }
          else
            jsonify(value.to_s)
          end
        end

        def encode_utf8(value)
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
