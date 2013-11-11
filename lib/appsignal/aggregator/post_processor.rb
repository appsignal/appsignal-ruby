module Appsignal
  class Aggregator
    class PostProcessor
      attr_reader :transactions

      def initialize(transactions)
        @transactions = transactions
      end

      def post_processed_queue!
        transactions.map do |transaction|
          transaction.events.each do |event|
            Appsignal.post_processing_middleware.invoke(event)
          end
          transaction.to_hash
        end
      end

      def self.default_middleware
        Middleware::Chain.new do |chain|
          chain.add Appsignal::Aggregator::Middleware::DeleteBlanks
          if defined?(::ActionView)
            chain.add Appsignal::Aggregator::Middleware::ActionViewSanitizer
          end
          if defined?(::ActiveRecord)
            chain.add Appsignal::Aggregator::Middleware::ActiveRecordSanitizer
          end
        end
      end
    end
  end
end
