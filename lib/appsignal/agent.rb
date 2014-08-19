module Appsignal
  class Agent
    ACTION = 'log_entries'.freeze

    attr_accessor :aggregator, :thread, :master_pid, :pid, :active, :sleep_time,
                  :transmitter, :subscriber, :paused

    def initialize
      return unless Appsignal.config.active?
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
      @active = true
      Appsignal.logger.info('Started Appsignal agent')
    end

    def active?
      !! @active
    end

    def start_thread
      Appsignal.logger.debug('Starting agent thread')
      @thread = Thread.new do
        begin
          sleep(rand(sleep_time))
          loop do
            send_queue if aggregator.has_transactions?
            Appsignal.logger.debug("Sleeping #{sleep_time}")
            sleep(sleep_time)
          end
        rescue Exception=>ex
          Appsignal.logger.error "#{ex.class} in agent thread: '#{ex.message}'"
          Appsignal.logger.error ex.backtrace.join('\n')
        end
      end
    end

    def restart_thread
      Appsignal.logger.debug 'Restarting agent thread'
      stop_thread
      start_thread
    end

    def stop_thread
      if @thread && @thread.alive?
        Appsignal.logger.debug 'Stopping agent thread'
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

    def resubscribe
      Appsignal.logger.debug('Resubscribing to notifications')
      unsubscribe
      subscribe
    end

    def unsubscribe
      Appsignal.logger.debug('Unsubscribing from notifications')
      ActiveSupport::Notifications.unsubscribe(@subscriber)
      @subscriber = nil
    end

    def enqueue(transaction)
      forked! if @pid != Process.pid
      if Appsignal.is_ignored_action?(transaction.action)
        Appsignal.logger.debug("Ignoring transaction: #{transaction.request_id} (#{transaction.action})")
        return
      end
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
      Appsignal.logger.info('Forked worker process')
      @active = true
      @pid = Process.pid
      Thread.exclusive do
        @aggregator = Aggregator.new
      end
      resubscribe
      restart_thread
    end

    def shutdown(send_current_queue=false, reason=nil)
      Appsignal.logger.info("Shutting down agent (#{reason})")
      @active = false
      unsubscribe
      stop_thread
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
        shutdown(false, 429)
      when 406
        Appsignal.logger.error 'Your appsignal gem cannot communicate with the API anymore, please upgrade.'
        shutdown(false, 406)
      when 402
        Appsignal.logger.error 'Payment required'
        shutdown(false, 402)
      when 401
        Appsignal.logger.error 'API token cannot be authorized'
        shutdown(false, 401)
      else
        Appsignal.logger.error "Unknown Appsignal response code: '#{code}'"
        clear_queue
      end
    end
  end
end
