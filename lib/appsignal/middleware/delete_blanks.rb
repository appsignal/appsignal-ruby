module Appsignal
  module Middleware
    class DeleteBlanks
      def call(event)
        event.payload.each do |key, value|
          event.payload.delete(key) if value.blank?
        end
        yield
      end
    end
  end
end
