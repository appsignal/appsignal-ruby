module Appsignal
  class Aggregator
    attr_reader :queue, :slowness_index, :counts

    def initialize(queue = [], slowness_index = {})
      @queue = queue
      @slowness_index = slowness_index
      @counts = {:regular_request => 0, :slow_request => 0, :exception => 0}
    end

    # truncates or reduces the size of event values of the transaction, and
    # adds it to the queue.
    #
    # @returns [ Array ] Array with transactions
    def add(transaction)
      case transaction.type
      when :regular_request
        transaction.truncate!
      when :slow_request
        pre_process_slowness!(transaction)
      when :exception
        transaction.convert_values_to_primitives!
      end
      counts[transaction.type] += 1
      queue << transaction
    end

    # Informs whether the queue has any transactions in it or not
    #
    # @returns [ Boolean ]
    def has_transactions?
      queue.any?
    end

    # Post process the queue and return it
    #
    # @returns [ Array ] Array of post processed Appsignal::Transaction objects
    def post_processed_queue!
      Appsignal.logger.debug("Post processing queue: #{counts.inspect}")
      Appsignal::Aggregator::PostProcessor.new(queue).post_processed_queue!
    end

    protected

    def similar_slowest(transaction)
      slowness_index[transaction.action]
    end

    def pre_process_slowness!(transaction)
      similar_slowest = similar_slowest(transaction)
      if similar_slowest
        if transaction.slower?(similar_slowest)
          slowness_index[transaction.action] = transaction
          transaction.convert_values_to_primitives!
          similar_slowest.truncate!
        else
          transaction.truncate!
        end
      else
        slowness_index[transaction.action] = transaction
        transaction.convert_values_to_primitives!
      end
    end
  end
end

