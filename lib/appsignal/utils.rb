require "appsignal/utils/params_sanitizer"
require "appsignal/utils/query_params_sanitizer"

module Appsignal
  # @api private
  module Utils
    def self.data_generate(body)
      Data.generate(body)
    end

    class Data
      class << self
        def generate(body)
          if body.is_a?(Hash)
            map_hash(body)
          elsif body.is_a?(Array)
            map_array(body)
          else
            raise TypeError, "Body of type #{body.class} should be a Hash or Array"
          end
        end

        def map_hash(hash_value)
          map = Appsignal::Extension.data_map_new
          hash_value.each do |key, value|
            key = key.to_s
            case value
            when String
              map.set_string(key, value)
            when Integer
              # An Integer too big for C-lang longs to fit
              bigint = 1 << 63
              if value >= bigint
                map.set_string(key, "bigint:#{value}")
              else
                map.set_integer(key, value)
              end
            when Float
              map.set_float(key, value)
            when TrueClass, FalseClass
              map.set_boolean(key, value)
            when NilClass
              map.set_nil(key)
            when Hash
              map.set_data(key, map_hash(value))
            when Array
              map.set_data(key, map_array(value))
            else
              map.set_string(key, value.to_s)
            end
          end
          map
        end

        def map_array(array_value)
          array = Appsignal::Extension.data_array_new
          array_value.each do |value|
            case value
            when String
              array.append_string(value)
            when Integer
              # An Integer too big for C-lang longs to fit
              bigint = 1 << 63
              if value >= bigint
                array.append_string("bigint:#{value}")
              else
                array.append_integer(value)
              end
            when Float
              array.append_float(value)
            when TrueClass, FalseClass
              array.append_boolean(value)
            when NilClass
              array.append_nil
            when Hash
              array.append_data(map_hash(value))
            when Array
              array.append_data(map_array(value))
            else
              array.append_string(value.to_s)
            end
          end
          array
        end
      end
    end

    def self.json_generate(body)
      JSON.generate(body)
    end

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
            Hash[value.map { |k, v| [jsonify(k), jsonify(v)] }]
          when Array
            value.map { |v| jsonify(v) }
          else
            jsonify(value.to_s)
          end
        end

        def encode_utf8(value)
          value.encode(
            "utf-8".freeze,
            :invalid => :replace,
            :undef   => :replace
          )
        end
      end
    end
  end
end
