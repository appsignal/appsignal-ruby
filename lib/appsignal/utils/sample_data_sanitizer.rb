# frozen_string_literal: true

module Appsignal
  module Utils
    class SampleDataSanitizer
      FILTERED = "[FILTERED]"
      RECURSIVE = "[RECURSIVE VALUE]"

      class << self
        def sanitize(value, filter_keys = [])
          sanitize_value(value, filter_keys, [])
        end

        private

        def sanitize_value(value, filter_keys, seen)
          case value
          when Hash
            sanitize_hash(value, filter_keys, seen)
          when Array
            sanitize_array(value, filter_keys, seen)
          when TrueClass, FalseClass, NilClass, Integer, String, Symbol, Float
            unmodified(value)
          when Time
            "#<Time: #{value.iso8601}>"
          when Date
            "#<Date: #{value.iso8601}>"
          else
            if defined?(::Rack::Multipart::UploadedFile) &&
                value.is_a?(::Rack::Multipart::UploadedFile)
              "#<Rack::Multipart::UploadedFile " \
                "original_filename: #{value.original_filename.inspect}, " \
                "content_type: #{value.content_type.inspect}" \
                ">"
            elsif defined?(::ActionDispatch::Http::UploadedFile) &&
                value.is_a?(::ActionDispatch::Http::UploadedFile)
              "#<ActionDispatch::Http::UploadedFile " \
                "original_filename: #{value.original_filename.inspect}, " \
                "content_type: #{value.content_type.inspect}" \
                ">"
            else
              inspected(value)
            end
          end
        end

        def sanitize_hash(source, filter_keys, seen)
          seen = seen.clone << source.object_id

          {}.tap do |hash|
            source.each_pair do |key, value|
              hash[key] =
                if seen.include?(value.object_id)
                  RECURSIVE
                elsif filter_keys.include?(key.to_s)
                  FILTERED
                else
                  sanitize_value(value, filter_keys, seen)
                end
            end
          end
        end

        def sanitize_array(source, filter_keys, seen)
          seen = seen.clone << source.object_id

          [].tap do |array|
            source.each_with_index do |item, index|
              array[index] =
                if seen.include?(item.object_id)
                  RECURSIVE
                else
                  sanitize_value(item, filter_keys, seen)
                end
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
