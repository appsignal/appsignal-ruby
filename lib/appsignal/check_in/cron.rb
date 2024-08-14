# frozen_string_literal: true

module Appsignal
  module CheckIn
    class Cron
      class << self
        # @api private
        def transmitter
          @transmitter ||= Appsignal::Transmitter.new(
            "#{Appsignal.config[:logging_endpoint]}/check_ins/json"
          )
        end
      end

      # @api private
      attr_reader :identifier, :digest

      def initialize(identifier:)
        @identifier = identifier
        @digest = SecureRandom.hex(8)
      end

      def start
        transmit_event("start")
      end

      def finish
        transmit_event("finish")
      end

      private

      def event(kind)
        {
          :identifier => @identifier,
          :digest => @digest,
          :kind => kind,
          :timestamp => Time.now.utc.to_i,
          :check_in_type => "cron"
        }
      end

      def transmit_event(kind)
        unless Appsignal.active?
          Appsignal.internal_logger.debug(
            "AppSignal not active, not transmitting cron check-in event"
          )
          return
        end

        response = self.class.transmitter.transmit(event(kind))

        if response.code.to_i >= 200 && response.code.to_i < 300
          Appsignal.internal_logger.debug(
            "Transmitted cron check-in `#{identifier}` (#{digest}) #{kind} event"
          )
        else
          Appsignal.internal_logger.error(
            "Failed to transmit cron check-in #{kind} event: status code was #{response.code}"
          )
        end
      rescue => e
        Appsignal.internal_logger.error("Failed to transmit cron check-in #{kind} event: #{e}")
      end
    end
  end
end
