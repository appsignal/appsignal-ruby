module Appsignal
  class ZippedPayload
    attr_reader :body

    def initialize(given_body)
      @body = Zlib::Deflate.deflate(
        Appsignal::ZippedPayload.json_generate(given_body),
        Zlib::BEST_SPEED
      )
    end

    protected

    def self.json_generate(given_body)
      JSON.generate(jsonify(given_body))
    end

    def self.jsonify(value)
      case value
      when String
        value.encode(
          'utf-8',
          :invalid => :replace,
          :undef   => :replace
        )
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
  end
end
