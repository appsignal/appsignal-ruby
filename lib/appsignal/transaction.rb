require 'socket'
require 'appsignal/transaction/transaction_formatter'

module Appsignal
  class Transaction
    def self.create(key, env)
      Thread.current[:appsignal_transaction_id] = key
      Appsignal.transactions[key] = Appsignal::Transaction.new(key, env)
    end

    def self.current
      Appsignal.transactions[Thread.current[:appsignal_transaction_id]]
    end

    attr_reader :id, :events, :exception, :env, :log_entry

    def initialize(id, env)
      @id = id
      @events = []
      @log_entry = nil
      @exception = nil
      @env = env
    end

    def request
      ActionDispatch::Request.new(@env)
    end

    def set_log_entry(event)
      @log_entry = event
    end

    def add_event(event)
      @events << event
    end

    def add_exception(ex)
      @exception = ex
    end

    def hostname
      @hostname ||= Socket.gethostname
    end

    def exception?
      !! exception
    end

    def slow_request?
      return false unless log_entry
      Appsignal.config[:slow_request_threshold] <= log_entry.duration
    end

    def to_hash
      if exception?
        TransactionFormatter.faulty(self)
      elsif slow_request?
        TransactionFormatter.slow(self)
      else
        TransactionFormatter.regular(self)
      end.to_hash
    end

    def complete!
      Thread.current[:appsignal_transaction_id] = nil
      current_transaction = Appsignal.transactions.delete(@id)
      if log_entry || exception?
        Appsignal.agent.add_to_queue(current_transaction.to_hash)
      end
    end
  end

end
