module Appsignal
  class ParamsSanitizer
    class << self
      def sanitize(params)
        sanitize_hash(params)
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
        when String
          value
        else
          value.inspect
        end
      end
    end
  end
end
