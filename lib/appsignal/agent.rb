module Appsignal
  class Agent
    attr_reader :queue, :active, :sleep_time, :slowest_transactions, :transmitter
    ACTION = 'log_entries'

    def initialize
      return unless Appsignal.active?
      @sleep_time = 60.0
      @slowest_transactions = {}
      @queue = []
      @retry_request = true
      @thread = Thread.new do
        while true do
          send_queue if @queue.any?
          sleep @sleep_time
        end
      end
      @transmitter = Transmitter.new(
        Appsignal.config[:endpoint],
        ACTION,
        Appsignal.config[:api_key]
      )
      Appsignal.logger.info 'Started the Appsignal agent'
    end

    def add_to_queue(transaction)
      if !transaction.exception? && transaction.action
        current_slowest_transaction = @slowest_transactions[transaction.action]
        if current_slowest_transaction
          if current_slowest_transaction.process_action_event.duration <
             transaction.process_action_event.duration
            current_slowest_transaction.clear_payload_and_events!
            @slowest_transactions[transaction.action] = transaction
          else
            transaction.clear_payload_and_events!
          end
        else
          @slowest_transactions[transaction.action] = transaction
        end
      end
      @queue << transaction
    end

    def send_queue
      Appsignal.logger.debug "Sending queue"
      begin
        handle_result transmitter.transmit(queue.map(&:to_hash))
      rescue Exception => ex
        Appsignal.logger.error "Exception while communicating with AppSignal: #{ex}"
        handle_result nil
      end
    end

    def handle_result(code)
      Appsignal.logger.debug "Queue sent, response code: #{code}"
      case code.to_i
      when 200
        good_response
      when 420 # Enhance Your Calm
        good_response
        @sleep_time = @sleep_time * 1.5
      when 413 # Request Entity Too Large
        good_response
        @sleep_time = @sleep_time / 1.5
      when 429
        Appsignal.logger.error "Too many requests sent, disengaging the agent"
        stop_logging
      when 406
        Appsignal.logger.error "Your appsignal gem cannot communicate with the API anymore, please upgrade. Disengaging the agent"
        stop_logging
      when 402
        Appsignal.logger.error "Payment required, disengaging the agent"
        stop_logging
      when 401
        Appsignal.logger.error "API token cannot be authorized, disengaging the agent"
        stop_logging
      else
        retry_once
      end
    end

    protected

    def good_response
      @queue = []
      @slowest_transactions = {}
      @retry_request = true
    end

    def retry_once
      if @retry_request
        @retry_request = false
      else
        @retry_request = true
        @queue = []
      end
    end

    def stop_logging
      ActiveSupport::Notifications.unsubscribe(Appsignal.subscriber)
      Thread.kill(@thread)
    end
  end
end
