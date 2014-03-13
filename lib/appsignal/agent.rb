module Appsignal
  class Agent
    ACTION = 'log_entries'.freeze

    attr_accessor :aggregator, :thread, :master_pid, :pid, :active, :sleep_time,
                  :transmitter, :subscriber, :paused

    def initialize
      return unless Appsignal.active?
      if Appsignal.config.env == 'development'
        @sleep_time = 10.0
      else
        @sleep_time = 60.0
      end
      @master_pid = Process.pid
      @pid = @master_pid
      @aggregator = Aggregator.new
      @transmitter = Transmitter.new(ACTION)
      subscribe
      start_thread
      Appsignal.logger.info('Started Appsignal agent')
    end

    def start_thread
      Appsignal.logger.debug('Starting agent thread')
      @thread = Thread.new do
        loop do
          Appsignal.logger.debug aggregator.queue.inspect
          send_queue if aggregator.has_transactions?
          Appsignal.logger.debug("Sleeping #{sleep_time}")
          sleep(sleep_time)
        end
      end
    end

    def restart_thread
      stop_thread
      start_thread
    end

    def stop_thread
      if @thread && @thread.alive?
        Appsignal.logger.debug 'Killing agent thread'
        Thread.kill(@thread)
      end
    end

    def subscribe
      Appsignal.logger.debug('Subscribing to notifications')
      # Subscribe to notifications that don't start with a !
      @subscriber = ActiveSupport::Notifications.subscribe(/^[^!]/) do |*args|
        if Appsignal::Transaction.current
          event = ActiveSupport::Notifications::Event.new(*args)
          if event.name.start_with?('process_action')
            Appsignal::Transaction.current.set_process_action_event(event)
          elsif event.name.start_with?('perform_job')
            Appsignal::Transaction.current.set_perform_job_event(event)
          end
          Appsignal::Transaction.current.add_event(event) unless paused
        end
      end
    end

    def enqueue(transaction)
      forked! if @pid != Process.pid
      Appsignal.logger.debug('Enqueueing transaction')
      aggregator.add(transaction)
    end

    def send_queue
      Appsignal.logger.debug('Sending queue')
      # Replace aggregator while making sure no thread
      # is adding to it's queue
      aggregator_to_be_sent = nil
      Thread.exclusive do
        aggregator_to_be_sent = aggregator
        @aggregator = Aggregator.new
      end

      begin
        handle_result(
          transmitter.transmit(aggregator_to_be_sent.post_processed_queue!)
        )
      rescue Exception => ex
        Appsignal.logger.error "#{ex.class} while sending queue: #{ex.message}"
        Appsignal.logger.error ex.backtrace.join('\n')
      end
    end

    def clear_queue
      Appsignal.logger.debug('Clearing queue')
      # Replace aggregator while making sure no thread
      # is adding to it's queue
      Thread.exclusive do
        @aggregator = Aggregator.new
      end
    end

    def forked!
      Appsignal.logger.debug('Forked worker process')
      @pid = Process.pid
      Thread.exclusive do
        @aggregator = Aggregator.new
      end
      restart_thread
    end

    def shutdown(send_current_queue=false)
      Appsignal.logger.info('Shutting down agent')
      ActiveSupport::Notifications.unsubscribe(subscriber)
      Thread.kill(thread) if thread
      send_queue if send_current_queue && @aggregator.has_transactions?
    end

    protected

    def handle_result(code)
      Appsignal.logger.debug "Queue sent, response code: #{code}"
      case code.to_i
      when 200 # ok
      when 420 # Enhance Your Calm
        Appsignal.logger.info 'Increasing sleep time since the server told us to'
        @sleep_time = sleep_time * 1.5
      when 413 # Request Entity Too Large
        Appsignal.logger.info 'Decreasing sleep time since our last push was too large'
        @sleep_time = sleep_time / 1.5
      when 429
        Appsignal.logger.error 'Too many requests sent'
        shutdown
      when 406
        Appsignal.logger.error 'Your appsignal gem cannot communicate with the API anymore, please upgrade.'
        shutdown
      when 402
        Appsignal.logger.error 'Payment required'
        shutdown
      when 401
        Appsignal.logger.error 'API token cannot be authorized'
        shutdown
      else
        Appsignal.logger.error "Unknown Appsignal response code: '#{code}'"
        clear_queue
      end
    end
  end
end
