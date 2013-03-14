module Appsignal
  class ParamsSanitizer
    class << self
      def sanitize(params)
        sanitize_hash(params)
      end

      def sanitize!(params)
        sanitize_value!(params)
      end

      protected

      def sanitize_hash(hash)
        out = {}
        hash.each_pair do |key, value|
          out[key] = sanitize_value(value)
        end
        out
      end

      def sanitize_array(array)
        array.map { |value| sanitize_value(value) }
      end

      def sanitize_value(value)
        case value
        when Hash
          sanitize_hash(value)
        when Array
          sanitize_array(value)
        when String, Fixnum
          value
        else
          value.inspect
        end
      end

      def sanitize_hash!(hash)
        hash.each_pair do |key, value|
          hash[key] = sanitize_value(value)
        end
        hash
      end

      def sanitize_array!(array)
        array.each_with_index do |item, index|
          array[index] = sanitize_value!(item)
        end
      end

      def sanitize_value!(value)
        case value
        when Hash
          sanitize_hash!(value)
        when Array
          sanitize_array!(value)
        when String
          value
        else
          value.inspect
        end
      end
    end
  end
end
