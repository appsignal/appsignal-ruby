module Appsignal
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
      Middleware::Chain.new
    end

  end
end
