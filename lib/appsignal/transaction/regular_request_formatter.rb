module Appsignal
  class TransactionFormatter
    class RegularRequestFormatter < Appsignal::TransactionFormatter

      def sanitized_event_payload(*args)
        {}
      end

    end
  end
end
