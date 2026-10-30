# frozen_string_literal: true

module Appsignal
  module Utils
    # Caches values derived from keys that form a small set in practice, such as
    # event names or template paths, so they are not derived again on every
    # event. Safe to share between threads.
    class BoundedCache
      # The keys come from the application, and nothing stops it from using a
      # new one for every event. Past this many keys the cache starts over, so
      # it never grows forever and keys first seen late still get cached.
      MAX_SIZE = 1000

      def initialize
        @values = {}
        @mutex = Mutex.new
      end

      def fetch(key)
        @mutex.synchronize do
          @values.fetch(key) do
            @values.clear if @values.size >= MAX_SIZE
            @values[key] = yield
          end
        end
      end
    end
  end
end
