module Appsignal
  PostProcessor = Struct.new(:transactions) do

    def initialize(pre_processed_transactions)
      @transactions = pre_processed_transactions
    end

    def self.default_middleware
      Middleware::Chain.new
    end

  end
end
