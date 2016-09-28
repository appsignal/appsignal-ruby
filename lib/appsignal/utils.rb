require 'appsignal/utils/params_sanitizer'
require 'appsignal/utils/query_params_sanitizer'

module Appsignal
  module Utils
    module ClassMethods
      extend Gem::Deprecate

      def sanitize(params, only_top_level = false, key_sanitizer = nil)
        QueryParamsSanitizer.sanitize(params, only_top_level, key_sanitizer)
      end

      deprecate :sanitize, "AppSignal::Utils::QueryParamsSanitizer.sanitize", 2016, 9
    end
    extend ClassMethods

    def self.json_generate(body)
      JSON.generate(body)
    end

    class JSON
      module ClassMethods
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
            'utf-8'.freeze,
            :invalid => :replace,
            :undef   => :replace
          )
        end
      end

      extend ClassMethods
    end

    class Gzip
      def self.compress(body)
        Zlib::Deflate.deflate(body, Zlib::BEST_SPEED)
      end
    end
  end
end
