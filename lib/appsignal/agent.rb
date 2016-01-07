module Appsignal
  class Agent
    ACTION = 'log_entries'.freeze
    AGGREGATOR_LIMIT = 3 # Three minutes with a sleep time of 60 seconds
    MUTEX_FOR_THREAD_EXCLUSIVE = Mutex.new # Ruby 2.3 deprecated Thread.exclusive

    attr_accessor :aggregator, :thread, :master_pid, :pid, :active, :sleep_time,
                  :transmitter, :subscriber, :paused, :aggregator_queue, :revision,
                  :transmission_successful

    def initialize
      return unless Appsignal.config.active?
      if Appsignal.config.env == 'development'
        @sleep_time = 10.0
      else
        @sleep_time = 60.0
      end
      @master_pid              = Process.pid
      @pid                     = @master_pid
      @aggregator              = Aggregator.new
      @transmitter             = Transmitter.new(ACTION)
      @aggregator_queue        = []
      @transmission_successful = true

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
      @revision = ENV['APP_REVISION']
      @thread   = Thread.new do
        begin
          sleep(rand(sleep_time))
          loop do
            if aggregator.has_transactions? || aggregator_queue.any?
              send_queue
            end
            truncate_aggregator_queue
            Appsignal.logger.debug("Sleeping #{sleep_time}")
            sleep(sleep_time)
          end
        rescue Exception=>ex
          Appsignal.logger.error "#{ex.class} in agent thread: '#{ex.message}'\n#{ex.backtrace.join("\n")}"
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
        # Some people abuse the notification system and send their own data over it
        # (looking at you, active_admin), make sure we only process valid events.
        if Appsignal::Transaction.current && args.length == 5
          event = Appsignal::Event.event_for_instrumentation(*args)
          if event.name.start_with?('process_action')
            Appsignal::Transaction.current.set_process_action_event(event)
          elsif event.name.start_with?('perform_job')
            Appsignal::Transaction.current.set_perform_job_event(event)
          end
          Appsignal::Transaction.current.add_event(event)
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
      unless aggregator.has_transactions? || aggregator_queue.any?
        return
      end
      # Replace aggregator while making sure no thread
      # is adding to it's queue
      aggregator_to_be_sent = nil
      MUTEX_FOR_THREAD_EXCLUSIVE.synchronize do
        aggregator_to_be_sent = aggregator
        @aggregator = Aggregator.new
      end

      begin
        payload = Appsignal::ZippedPayload.new(aggregator_to_be_sent.post_processed_queue!)
        add_to_aggregator_queue(payload)
        send_aggregators
      rescue Exception => ex
        Appsignal.logger.error "#{ex.class} while sending queue: #{ex.message}\n#{ex.backtrace.join("\n")}"
      end
    end

    def add_to_aggregator_queue(aggregator)
      @aggregator_queue.unshift(aggregator)
    end

    def send_aggregators
      @aggregator_queue.map! do |payload|
        begin
          if handle_result(transmitter.transmit(payload))
            nil
          else
            payload
          end
        rescue *Transmitter::HTTP_ERRORS => ex
          Appsignal.logger.error "#{ex} while sending aggregators"
          payload
        end
      end.compact!
      @transmission_successful = @aggregator_queue.empty?
    end

    def truncate_aggregator_queue(limit = AGGREGATOR_LIMIT)
      return unless @aggregator_queue.length > limit
      Appsignal.logger.error "Aggregator queue to large, removing items"
      @aggregator_queue = @aggregator_queue.first(limit)
    end

    def forked!
      Appsignal.logger.info('Forked worker process')
      @active = true
      @pid = Process.pid
      MUTEX_FOR_THREAD_EXCLUSIVE.synchronize do
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

      # Only attempt to send the queue on shutdown when there are no API issues
      if send_current_queue && @transmission_successful
        send_queue
      end
    end

    protected

    def handle_result(code)
      Appsignal.logger.debug "Queue sent, response code: #{code}"
      case code.to_i
      when 200 # ok
        true
      when 420 # Enhance Your Calm
        Appsignal.logger.info 'Increasing sleep time since the server told us to'
        @sleep_time = sleep_time * 1.5
        true
      when 413 # Request Entity Too Large
        Appsignal.logger.info 'Decreasing sleep time since our last push was too large'
        @sleep_time = sleep_time / 1.5
        true
      when 429
        Appsignal.logger.error 'Too many requests sent'
        shutdown(false, 429)
        true
      when 406
        Appsignal.logger.error 'Your appsignal gem cannot communicate with the API anymore, please upgrade.'
        shutdown(false, 406)
        true
      when 402
        Appsignal.logger.error 'Payment required'
        shutdown(false, 402)
        true
      when 401
        Appsignal.logger.error 'API token cannot be authorized'
        shutdown(false, 401)
        true
      when 400
        Appsignal.logger.error 'Empty body sent'
        true
      else
        Appsignal.logger.error "Unknown Appsignal response code: '#{code}'"
        false
      end
    end
  end
end
