require 'json'

module Appsignal
  class Agent
    class Aggregator
      attr_reader :transactions, :event_details

      def initialize
        @transactions  = []
        @event_details = []
      end

      def add_transaction(transaction)
        @transactions << transaction
      end

      def add_event_details(digest, name, title, body)
        @event_details << {
          :digest  => digest,
          :name    => name,
          :title   => title,
          :body    => body
        }
      end

      def any?
        @transactions.any? ||
        @event_details.any?
      end

      def to_json
        JSON.fast_generate(
          :transactions  => @transactions,
          :event_details => @event_details,
        )
      end
    end
  end
end
