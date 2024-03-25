# frozen_string_literal: true

require "net/http"
require "json"

module Appsignal
  class Heartbeat
    @transmitter = nil

    def self.transmitter
      @transmitter ||= Appsignal::Transmitter.new(
        "#{Appsignal.config[:logging_endpoint]}/heartbeats/json"
      )
    end

    attr_reader :name, :id

    def initialize(name:)
      @name = name
      @id = SecureRandom.hex(8)
    end

    def start
      transmit_event("Start")
    end

    def finish
      transmit_event("Finish")
    end

    private

    def event(kind)
      {
        :name => name,
        :id => @id,
        :kind => kind,
        :timestamp => Time.now.utc.to_i
      }
    end

    def transmit_event(kind)
      self.class.transmitter.transmit(event(kind))
    end
  end

  def self.heartbeat(name)
    heartbeat = Appsignal::Heartbeat.new(:name => name)
    output = nil

    if block_given?
      heartbeat.start
      output = yield
    end

    heartbeat.finish
    output
  end
end
