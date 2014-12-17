module Appsignal
  class Agent
    attr_accessor :aggregator, :thread, :master_pid, :pid, :active, :sleep_time,
                  :subscriber, :paused, :aggregator_transmitter, :added_event_digests

    def initialize
      return unless Appsignal.config.active?

      if Appsignal.config.env == 'development'
        @sleep_time = 10.0
      else
        @sleep_time = 60.0
      end
      @master_pid                = Process.pid
      @pid                       = @master_pid
      @added_event_digests       = {}
      @aggregator                = Appsignal::Agent::Aggregator.new
      @aggregator_transmitter    = Appsignal::Agent::AggregatorTransmitter.new(self)
      @subscriber                = Appsignal::Agent::Subscriber.new(self)
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
            replace_aggregator_and_transmit
            Appsignal.logger.debug("Sleeping #{sleep_time}")
            sleep(sleep_time)
          end
        rescue Exception=>ex
          Appsignal.logger.error "#{ex.class} in agent thread: '#{ex.message}'\n#{ex.backtrace.join("\n")}"
        end
      end
    end

    def stop_thread
      if @thread && @thread.alive?
        Appsignal.logger.debug 'Stopping agent thread'
        Thread.kill(@thread)
      end
    end

    def restart_thread
      Appsignal.logger.debug 'Restarting agent thread'
      stop_thread
      start_thread
    end

    def add_transaction(transaction)
      forked! if @pid != Process.pid
      if Appsignal.is_ignored_action?(transaction.action)
        Appsignal.logger.debug("Ignoring transaction: #{transaction.request_id} (#{transaction.action})")
        return
      end
      aggregator.add_transaction(transaction)
    end

    def add_event_details(digest, name, title, body)
      unless added_event_digests[digest]
        added_event_digests[digest] = true
        aggregator.add_event_details(digest, name, title, body)
      end
    end

    def replace_aggregator_and_transmit
      Appsignal.logger.debug('Sending queue')
      # Replace aggregator while making sure no thread
      # is adding to it's queue
      aggregator_to_be_sent = nil
      Thread.exclusive do
        aggregator_to_be_sent = aggregator
        @aggregator = Appsignal::Agent::Aggregator.new
      end

      begin
        aggregator_transmitter.add(aggregator_to_be_sent) if aggregator_to_be_sent.any?
        aggregator_transmitter.transmit
        aggregator_transmitter.truncate
      rescue Exception => ex
        Appsignal.logger.error "#{ex.class} while transmitting aggregators: #{ex.message}\n#{ex.backtrace.join("\n")}"
      end
    end

    def forked!
      Appsignal.logger.info('Forked worker process')
      @active = true
      @pid = Process.pid
      Thread.exclusive do
        @aggregator = Aggregator.new
      end
      subscriber.resubscribe
      restart_thread
    end

    def shutdown(transmit=false, reason=nil)
      Appsignal.logger.info("Shutting down agent (#{reason})")
      @active = false
      subscriber.unsubscribe if subscriber
      stop_thread
      replace_aggregator_and_transmit if transmit
    end
  end
end
