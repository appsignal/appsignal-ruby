module Appsignal
  class Agent
    attr_accessor :aggregator, :thread, :active, :sleep_time,
                  :subscriber, :paused, :aggregator_transmitter, :added_event_digests

    def initialize
      return unless Appsignal.config.active?

      @subscriber                = Appsignal::Agent::Subscriber.new(self)
      @active = true

      Appsignal.logger.info('Started Appsignal agent')
    end

    def active?
      !! @active
    end
  end
end
