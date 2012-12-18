require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Appsignal
  class Transmitter
    attr_accessor :endpoint, :action, :api_key

    def initialize(endpoint, action, api_key, logger=nil)
      @endpoint = endpoint
      @action = action
      @api_key = api_key
    end

    def uri
      URI("#{@endpoint}/#{@action}").tap do |uri|
        uri.query = URI.encode_www_form({
          :api_key => api_key,
          :gem_version => Appsignal::VERSION
        })
      end
    end

    def transmit(payload)
      result = http_client.request(message(payload))
      result.code
    end

    def message(payload)
      Net::HTTP::Post.new(uri.request_uri).tap do |post|
        post.body = payload.to_json
      end
    end

    protected

    def ca_file_path
      File.expand_path(File.join(__FILE__, '../../../resources/cacert.pem'))
    end

    def http_client
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_file = ca_file_path
        end
      end
    end
  end
end
