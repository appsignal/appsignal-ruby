# frozen_string_literal: true

require "net/http"
require "net/https"
require "uri"
require "rack/utils"
require "json"

module Appsignal
  # @api private
  class Transmitter
    CONTENT_TYPE = "application/json; charset=UTF-8"

    HTTP_ERRORS = [
      EOFError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EINVAL,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::ProtocolError,
      Timeout::Error,
      OpenSSL::SSL::SSLError
    ].freeze

    attr_reader :config, :base_uri

    # @param base_uri [String] Base URI for the transmitter to use. If a full
    #   URI is given (including the HTTP protocol) it is used as the full base.
    #   If only a path is given the `config[:endpoint]` is prefixed along with
    #   `/1/` (API v1 endpoint).
    # @param config [Appsignal::Config] AppSignal configuration to use for this
    #   transmission.
    def initialize(base_uri, config = Appsignal.config)
      @base_uri =
        if base_uri.start_with? "http"
          base_uri
        else
          "#{config[:endpoint]}/1/#{base_uri}"
        end
      @config = config
    end

    def uri
      @uri ||= URI(base_uri).tap do |uri|
        uri.query = ::Rack::Utils.build_query(
          :api_key => config[:push_api_key],
          :name => config[:name],
          :environment => config.env,
          :hostname => config[:hostname],
          :gem_version => Appsignal::VERSION
        )
      end
    end

    def transmit(payload)
      config.logger.debug "Transmitting payload to #{uri}"
      http_client.request(http_post(payload))
    end

    private

    def http_post(payload)
      Net::HTTP::Post.new(uri.request_uri).tap do |request|
        request["Content-Type"] = CONTENT_TYPE
        request.body = Appsignal::Utils::JSON.generate(payload)
      end
    end

    def http_client
      client =
        if config[:http_proxy]
          Net::HTTP.new(uri.host, uri.port, proxy_addr, proxy_port)
        else
          Net::HTTP.new(uri.host, uri.port)
        end

      client.tap do |http|
        if uri.scheme == "https"
          http.use_ssl     = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER

          ca_file = config[:ca_file_path]
          if ca_file && File.exist?(ca_file) && File.readable?(ca_file)
            http.ca_file = ca_file
          else
            config.logger.warn "Ignoring non-existing or unreadable " \
              "`ca_file_path`: #{ca_file}"
          end
        end
      end
    end

    def proxy_uri
      @proxy_uri ||= URI.parse(config[:http_proxy])
    end

    def proxy_addr
      return unless config[:http_proxy]

      proxy_uri.host
    end

    def proxy_port
      return unless config[:http_proxy]

      proxy_uri.port
    end
  end
end
