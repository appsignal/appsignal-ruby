module Appsignal
  class << self
    remove_method :testing?

    def testing?
      true
    end
  end

  module Testing
    class << self
      attr_writer :keep_transactions
      # @see TransactionHelpers#keep_transactions
      def keep_transactions?
        defined?(@keep_transactions) ? @keep_transactions : nil
      end

      attr_writer :sample_transactions
      # @see TransactionHelpers#keep_transactions
      def sample_transactions?
        sample = defined?(@sample_transactions) ? @sample_transactions : nil
        if sample.nil?
          keep_transactions?
        else
          @sample_transactions
        end
      end
    end
  end

  class Extension
    class Transaction
      alias original_finish finish

      # Override default {Extension::Transaction#finish} behavior to always
      # return true, which tells the transaction to add its sample data (unless
      # used in combination with {TransactionHelpers#keep_transactions}
      # `:sample => false`). This allows us to use
      # {Appsignal::Transaction#to_h} without relying on the extension sampling
      # behavior.
      #
      # @see TransactionHelpers#keep_transactions
      def finish(*args)
        return_value = original_finish(*args)
        return_value = true if Appsignal::Testing.sample_transactions?
        return_value
      end

      alias original_complete complete

      # Override default {Extension::Transaction#complete} behavior to
      # store the transaction JSON before the transaction is completed
      # and it's no longer possible to request the transaction JSON.
      #
      # @see TransactionHelpers#keep_transactions
      def complete
        @transaction_json = to_json if Appsignal::Testing.keep_transactions?
        original_complete
      end

      alias original_to_json to_json

      # Override default {Extension::Transaction#to_json} behavior to
      # return the stored the transaction JSON when the transaction was
      # completed.
      #
      # @see TransactionHelpers#keep_transactions
      def to_json
        if defined? @transaction_json
          @transaction_json
        else
          original_to_json
        end
      end
    end
  end
end
