module Appsignal
  module Utils
    def self.sanitize(params, only_top_level=false, key_sanitizer=nil)
      if params.is_a?(Hash)
        {}.tap do |hsh|
          params.each do |key, val|
            hsh[self.sanitize_key(key, key_sanitizer)] = if only_top_level
              '?'
            else
              sanitize(val, only_top_level, key_sanitizer=nil)
            end
          end
        end
      elsif params.is_a?(Array)
        if only_top_level
          sanitize(params[0], only_top_level, key_sanitizer=nil)
        else
          params.map do |item|
            sanitize(item, only_top_level, key_sanitizer=nil)
          end.uniq
        end
      else
        '?'
      end
    end

    def self.sanitize_key(key, sanitizer)
      case sanitizer
      when :mongodb then key.to_s.gsub(/(\..+)/, '.?')
      else key
      end
    end
  end
end
