# frozen_string_literal: true

module Appsignal
  module Utils
    class RequestHeaders
      # The only two request headers Rack passes without the `HTTP_` prefix,
      # because CGI reserves the prefixed spelling of them.
      UNPREFIXED_HEADER_KEYS = %w[CONTENT_LENGTH CONTENT_TYPE].freeze

      # `HTTP_VERSION` is a CGI variable holding the same value as
      # `SERVER_PROTOCOL`, not a header.
      NON_HEADER_KEYS = %w[HTTP_VERSION].freeze

      # The environment keys the instrumentation already describes with a semantic
      # convention attribute, read from the request itself.
      TRANSLATED_ENV_KEYS = %w[
        PATH_INFO REQUEST_METHOD REQUEST_PATH SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ].freeze

      HTTP_PREFIX = "HTTP_"

      class << self
        def split(env)
          headers = {}
          environment = {}

          env.each do |key, value|
            name = header_name(key)
            if name
              headers[name] = value
            else
              environment[key] = value
            end
          end

          [headers, environment]
        end

        def header_name(env_key)
          env_key = env_key.to_s
          return if NON_HEADER_KEYS.include?(env_key)

          if env_key.start_with?(HTTP_PREFIX)
            clean(env_key.delete_prefix(HTTP_PREFIX))
          elsif UNPREFIXED_HEADER_KEYS.include?(env_key)
            clean(env_key)
          end
        end

        # A key does not always make the round trip as itself, because two Rack keys
        # can name the same header: a server that sets both `CONTENT_LENGTH` and
        # `HTTP_CONTENT_LENGTH` gets the second one back as the first.
        def rack_name(header)
          env_key = header.to_s.upcase.tr("-", "_")
          return env_key if UNPREFIXED_HEADER_KEYS.include?(env_key)

          "#{HTTP_PREFIX}#{env_key}"
        end

        private

        def clean(env_key)
          env_key.downcase.tr("_", "-")
        end
      end
    end
  end
end
