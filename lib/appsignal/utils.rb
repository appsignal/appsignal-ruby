module Appsignal
  module Utils
    def self.sanitize(params, only_top_level=false)
      if params.is_a?(Hash)
        {}.tap do |hsh|
          params.each do |key, val|
            hsh[key] = only_top_level ? '?' : sanitize(val, only_top_level)
          end
        end
      elsif params.is_a?(Array)
        if only_top_level
          sanitize(params[0], only_top_level)
        elsif params.first.is_a?(String)
          ['?']
        else
          params.map do |item|
            sanitize(item, only_top_level)
          end
        end
      else
        '?'
      end
    end
  end
end
