# frozen_string_literal: true

module Appsignal
  module Utils
    # Tells HTTP request headers apart from the CGI variables Rack mixes them
    # in with, and maps a header between the two names it goes by. Rack calls
    # the `Accept` header `HTTP_ACCEPT`; OpenTelemetry calls it `accept`.
    #
    # Both directions live here so that they cannot drift apart.
    class RequestHeaders
      # The only two request headers Rack passes without the `HTTP_` prefix,
      # because CGI reserves the prefixed spelling of them.
      UNPREFIXED_HEADER_KEYS = %w[CONTENT_LENGTH CONTENT_TYPE].freeze

      # `HTTP_VERSION` is a CGI variable holding the same value as
      # `SERVER_PROTOCOL`, not a header. A client that sends a real `Version`
      # header arrives under the same key, so that header is reported as an
      # environment value rather than as a header. `Version` is not a
      # registered HTTP header, so that is the cheaper of the two mistakes.
      NON_HEADER_KEYS = %w[HTTP_VERSION].freeze

      # The environment keys the Rack and Webmachine instrumentation already
      # describes with a semantic convention attribute, which it reads from the
      # request itself. Reporting them as environment values as well would say
      # the same thing twice, in a worse form: `PATH_INFO` drops the mount
      # prefix that `url.path` keeps, and `SERVER_NAME` ignores the forwarded
      # host that `server.address` follows.
      TRANSLATED_ENV_KEYS = %w[
        PATH_INFO REQUEST_METHOD REQUEST_PATH SERVER_NAME SERVER_PORT
        SERVER_PROTOCOL
      ].freeze

      HTTP_PREFIX = "HTTP_"

      class << self
        # Splits a Rack environment into the request headers it holds, named
        # the way OpenTelemetry names them, and everything else, which keeps
        # its Rack name.
        #
        # A value that is not a Hash cannot be split, so it goes to the
        # environment side unchanged and whatever rejects it there can say so.
        #
        # @param env [Hash<String, Object>]
        # @return [Array(Hash<String, Object>, Hash<String, Object>)]
        def split(env)
          return [{}, env] unless env.is_a?(Hash)

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

        # Returns a pair of blocks that split what `block` returns, the first
        # giving the request headers and the second the rest of the
        # environment.
        #
        # Used to feed the two channels of a transaction from one Rack
        # environment. Both blocks run when the transaction is sampled, and
        # `block` runs once however many of them are called.
        #
        # @return [Array(Proc, Proc)]
        def split_lazily(&block)
          split = nil
          splitter = lambda { split ||= split(block.call) }

          [lambda { splitter.call.first }, lambda { splitter.call.last }]
        end

        # The OpenTelemetry name of the header a Rack environment key holds, or
        # `nil` when the key holds something that is not a header.
        #
        # @param env_key [String]
        # @return [String, nil]
        def header_name(env_key)
          env_key = env_key.to_s
          return if NON_HEADER_KEYS.include?(env_key)

          if env_key.start_with?(HTTP_PREFIX)
            clean(env_key.delete_prefix(HTTP_PREFIX))
          elsif UNPREFIXED_HEADER_KEYS.include?(env_key)
            clean(env_key)
          end
        end

        # The Rack environment key a header's OpenTelemetry name maps back to.
        #
        # A key that makes the round trip is not always the one it started as,
        # because two Rack keys can name the same header. A server that sets
        # both `CONTENT_LENGTH` and `HTTP_CONTENT_LENGTH` gives the second one
        # back as the first, since that is the spelling Rack is supposed to
        # use. Rack itself has the same problem earlier on, folding the `X-Foo`
        # and `X_Foo` headers into one `HTTP_X_FOO` key.
        #
        # @param header [String]
        # @return [String]
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
