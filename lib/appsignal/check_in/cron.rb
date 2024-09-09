# frozen_string_literal: true

module Appsignal
  module CheckIn
    class Cron
      # @api private
      attr_reader :identifier, :digest

      def initialize(identifier:)
        @identifier = identifier
        @digest = SecureRandom.hex(8)
      end

      def start
        CheckIn.scheduler.schedule(event("start"))
      end

      def finish
        CheckIn.scheduler.schedule(event("finish"))
      end

      private

      def event(kind)
        Event.cron(
          :identifier => @identifier,
          :digest => @digest,
          :kind => kind
        )
      end
    end
  end
end
