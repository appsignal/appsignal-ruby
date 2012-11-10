module Appsignal
  class Agent
    attr_reader :queue, :active, :sleep_time, :transmitter
    ACTION = 'log_entries'

    def initialize
      return unless Appsignal.active
      @sleep_time = 5.0
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
      Appsignal.logger.info "Started the Appsignal agent"
    end

    def add_to_queue(transaction)
      @queue << transaction
    end

    def send_queue
      Appsignal.logger.debug "Sending queue"
      begin
        handle_result transmitter.transmit(:log_entries => queue)
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
      when 429 # Too Many Requests (RFC 6585)
        stop_logging
      when 402 # Payment Grace period expired
        stop_logging
      else
        retry_once
      end
    end

    protected

    def good_response
      @queue = []
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
      Appsignal.logger.error "Something went wrong, disengaging the agent"
      ActiveSupport::Notifications.unsubscribe(Appsignal.subscriber)
      Thread.kill(@thread)
    end
  end
end
