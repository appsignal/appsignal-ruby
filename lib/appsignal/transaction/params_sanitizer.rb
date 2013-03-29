module Appsignal
  class ParamsSanitizer
    class << self
      def sanitize(params)
        ParamsSanitizerCopy.sanitize_value(params)
      end

      def sanitize!(params)
        ParamsSanitizerDestructive.sanitize_value(params)
      end

      protected

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

      def sanitize_hash_with_target(source_hash, target_hash)
        source_hash.each_pair do |key, value|
          target_hash[key] = sanitize_value(value)
        end
        target_hash
      end

      def sanitize_array_with_target(source_array, target_array)
        source_array.each_with_index do |item, index|
          target_array[index] = sanitize_value(item)
        end
        target_array
      end
    end
  end

  class ParamsSanitizerCopy < ParamsSanitizer
    class << self
      protected

      def sanitize_hash(hash)
        sanitize_hash_with_target(hash, {})
      end

      def sanitize_array(array)
        sanitize_array_with_target(array, [])
      end
    end
  end

  class ParamsSanitizerDestructive < ParamsSanitizer
    class << self
      protected

      def sanitize_hash(hash)
        sanitize_hash_with_target(hash, hash)
      end

      def sanitize_array(array)
        sanitize_array_with_target(array, array)
      end
    end
  end
end
