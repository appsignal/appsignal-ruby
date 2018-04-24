# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    class ParamsSanitizer
      FILTERED = "[FILTERED]".freeze

      class << self
        def sanitize(params, options = {})
          sanitize_value(params, options.fetch(:filter_parameters, []))
        end

        private

        def sanitize_value(value, filter_parameter_keys)
          case value
          when Hash
            sanitize_hash(value, filter_parameter_keys)
          when Array
            sanitize_array(value, filter_parameter_keys)
          when TrueClass, FalseClass, NilClass, Integer, String, Symbol, Float
            unmodified(value)
          else
            inspected(value)
          end
        end

        def sanitize_hash(source, filter_parameter_keys)
          {}.tap do |hash|
            source.each_pair do |key, value|
              hash[key] =
                if filter_parameter_keys.include?(key.to_s)
                  FILTERED
                else
                  sanitize_value(value, filter_parameter_keys)
                end
            end
          end
        end

        def sanitize_array(source, filter_parameter_keys)
          [].tap do |array|
            source.each_with_index do |item, index|
              array[index] = sanitize_value(item, filter_parameter_keys)
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
