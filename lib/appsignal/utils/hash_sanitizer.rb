# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    class HashSanitizer
      FILTERED = "[FILTERED]"

      class << self
        def sanitize(value, filter_keys = [])
          sanitize_value(value, filter_keys)
        end

        private

        def sanitize_value(value, filter_keys)
          case value
          when Hash
            sanitize_hash(value, filter_keys)
          when Array
            sanitize_array(value, filter_keys)
          when TrueClass, FalseClass, NilClass, Integer, String, Symbol, Float
            unmodified(value)
          else
            inspected(value)
          end
        end

        def sanitize_hash(source, filter_keys)
          {}.tap do |hash|
            source.each_pair do |key, value|
              hash[key] =
                if filter_keys.include?(key.to_s)
                  FILTERED
                else
                  sanitize_value(value, filter_keys)
                end
            end
          end
        end

        def sanitize_array(source, filter_keys)
          [].tap do |array|
            source.each_with_index do |item, index|
              array[index] = sanitize_value(item, filter_keys)
            end
          end
        end

        def unmodified(value)
          value
        end

        def inspected(value)
          "#<#{value.class}>"
        end
      end
    end
  end
end
