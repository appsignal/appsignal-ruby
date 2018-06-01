# frozen_string_literal: true

require "appsignal/utils/data"
require "appsignal/utils/hash_sanitizer"
require "appsignal/utils/json"
require "appsignal/utils/query_params_sanitizer"

module Appsignal
  # @api private
  module Utils
    def self.data_generate(body)
      Utils::Data.generate(body)
    end

    def self.json_generate(body)
      Utils::JSON.generate(body)
    end
  end
end
