module Appsignal
  module Utils
    class ParamsSanitizer
      FILTERED = "[FILTERED]".freeze

      class << self
        def sanitize(params, options = {})
          sanitize_value(params, options)
        end

        private

        def sanitize_value(value, options = {})
          case value
          when Hash
            sanitize_hash(value, options)
          when Array
            sanitize_array(value, options)
          when TrueClass, FalseClass, NilClass, Fixnum, String, Symbol, Float
            unmodified(value)
          else
            inspected(value)
          end
        end

        def sanitize_hash(source, options)
          filter_keys = options.fetch(:filter_parameters, [])
          {}.tap do |hash|
            source.each_pair do |key, value|
              hash[key] =
                if filter_keys.include?(key.to_s)
                  FILTERED
                else
                  sanitize_value(value, options)
                end
            end
          end
        end

        def sanitize_array(source, options)
          [].tap do |array|
            source.each_with_index do |item, index|
              array[index] = sanitize_value(item, options)
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
