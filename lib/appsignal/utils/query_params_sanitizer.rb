# frozen_string_literal: true

module Appsignal
  module Utils
    # @api private
    class QueryParamsSanitizer
      REPLACEMENT_KEY = "?"

      module ClassMethods
        def sanitize(params, only_top_level = false, key_sanitizer = nil)
          case params
          when Hash
            sanitize_hash params, only_top_level, key_sanitizer
          when Array
            sanitize_array params, only_top_level, key_sanitizer
          else
            REPLACEMENT_KEY
          end
        end

        private

        def sanitize_hash(hash, only_top_level, key_sanitizer)
          {}.tap do |h|
            hash.each do |key, value|
              h[sanitize_key(key, key_sanitizer)] =
                if only_top_level
                  REPLACEMENT_KEY
                else
                  sanitize(value, only_top_level, key_sanitizer)
                end
            end
          end
        end

        def sanitize_array(array, only_top_level, key_sanitizer)
          if only_top_level
            [sanitize(array[0], only_top_level, key_sanitizer)]
          else
            array.map do |value|
              sanitize(value, only_top_level, key_sanitizer)
            end.uniq
          end
        end

        def sanitize_key(key, sanitizer)
          case sanitizer
          when :mongodb then key.to_s.gsub(/(\..+)/, ".#{REPLACEMENT_KEY}")
          else key
          end
        end
      end

      extend ClassMethods
    end
  end
end
