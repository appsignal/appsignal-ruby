module Appsignal
  PostProcessor = Struct.new(:transactions) do

    def initialize(pre_processed_transactions)
      @transactions = pre_processed_transactions
    end

    def self.default_middleware
      Middleware::Chain.new
    end

    def post_processed_queue!
      @transactions.each do |transaction|
        Appsignal.post_processing_middleware.invoke(
          transaction.process_action_event,
          transaction.events
        ) do
          transaction.to_hash
        end
      end
    end

  end
end
