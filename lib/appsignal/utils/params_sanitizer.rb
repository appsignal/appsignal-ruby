module Appsignal
  module Utils
    class ParamsSanitizer
      class << self
        def sanitize(params)
          sanitize_value(params)
        end

        private

        def sanitize_value(value)
          case value
          when Hash
            sanitize_hash(value)
          when Array
            sanitize_array(value)
          when TrueClass, FalseClass, NilClass, Fixnum, String, Symbol, Float
            unmodified(value)
          else
            inspected(value)
          end
        end

        def sanitize_hash(source)
          {}.tap do |hash|
            source.each_pair do |key, value|
              hash[key] = sanitize_value(value)
            end
          end
        end

        def sanitize_array(source)
          [].tap do |array|
            source.each_with_index do |item, index|
              array[index] = sanitize_value(item)
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
