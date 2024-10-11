# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ActiveSupport
      class CacheFormatter
        def format(payload)
          key = payload[:key]
          title = case key
                  when Hash then key.keys
                  when Array then key
                  else [key]
                  end.map(&:to_s).sort.join(", ")
          [title, nil]
        end
      end
    end
  end
end

[
  :delete,
  :delete_multi,
  :exist?,
  :fetch,
  :read,
  :read_multi,
  :write,
  :write_multi
].each do |action|
  Appsignal::EventFormatter.register(
    "cache_#{action}.active_support",
    Appsignal::EventFormatter::ActiveSupport::CacheFormatter
  )
end
