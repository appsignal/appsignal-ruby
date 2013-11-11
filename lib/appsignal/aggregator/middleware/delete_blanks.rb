module Appsignal
  class Aggregator
    module Middleware
      class DeleteBlanks
        def call(event)
          event.payload.each do |key, value|
            if value.respond_to?(:empty?) ? value.empty? : !value
              event.payload.delete(key)
            end
          end
          yield
        end
      end
    end
  end
end
