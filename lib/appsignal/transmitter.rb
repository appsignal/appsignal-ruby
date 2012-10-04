require 'net/http'
require 'net/https'
require 'uri'
require 'json'

module Appsignal
  class Transmitter

    attr_accessor :endpoint, :action, :api_key

    def initialize(endpoint, action, api_key)
      @endpoint = endpoint
      @action = action
      @api_key = api_key
    end

    def uri
      URI("#{@endpoint}/#{@action}")
    end

    def transmit(payload)
      begin
       result = http_client.request(encoded_message(payload))
       result.code
      rescue
        nil
      end
    end

    def encoded_message(payload)
      encoded_payload = {}.tap do |hsh|
        payload.each do |key, val|
          hsh[key] = JSON.generate(val)
        end
      end
      message(encoded_payload)
    end

    def message(encoded_hash)
      Net::HTTP::Post.new(uri.request_uri).tap do |post|
        post.set_form_data(
          {
            :api_key => api_key,
            :gem_version => Appsignal::VERSION
          }.merge(encoded_hash)
        )
      end
    end

    protected

    def http_client
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end
      end
    end

  end
end
