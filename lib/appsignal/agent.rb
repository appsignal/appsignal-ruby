module Appsignal
  class Agent
    ACTION = 'log_entries'

    attr_reader :aggregator, :active, :sleep_time, :transmitter

    def initialize
      return unless Appsignal.active?
      @sleep_time = 60.0
      @aggregator = Aggregator.new
      @retry_request = true
      @thread = Thread.new do
        while true do
          send_queue if @queue.any?
          sleep @sleep_time
        end
      end
      @transmitter = Transmitter.new(
        Appsignal.config.fetch(:endpoint),
        ACTION,
        Appsignal.config.fetch(:api_key)
      )
      Appsignal.logger.info 'Started the Appsignal agent'
    end

    def enqueue(transaction)
      aggregator.add(transaction)
    end

    def send_queue
      Appsignal.logger.debug "Sending queue"
      begin
        queue = aggregator
        @aggregator = Aggregator.new
        handle_result transmitter.transmit(queue.post_processed_queue!)
      rescue Exception => ex
        Appsignal.logger.error "Exception while communicating with "\
          "AppSignal: #{ex}"
        handle_result nil
      end
    end

    protected

    def handle_result(code)
      Appsignal.logger.debug "Queue sent, response code: #{code}"
      case code.to_i
      when 200 # ok
      when 420 # Enhance Your Calm
        @sleep_time = @sleep_time * 1.5
      when 413 # Request Entity Too Large
        @sleep_time = @sleep_time / 1.5
      when 429
        Appsignal.logger.error "Too many requests sent"
        stop_logging
      when 406
        Appsignal.logger.error "Your appsignal gem cannot communicate with "\
          "the API anymore, please upgrade."
        stop_logging
      when 402
        Appsignal.logger.error "Payment required"
        stop_logging
      when 401
        Appsignal.logger.error "API token cannot be authorized"
        stop_logging
      else
        Appsignal.logger.error "Unknown Appsignal response code: '#{code}'"
      end
    end

    def stop_logging
      Appsignal.logger.info("Disengaging the agent")
      ActiveSupport::Notifications.unsubscribe(Appsignal.subscriber)
      Thread.kill(@thread)
    end

  end
end
