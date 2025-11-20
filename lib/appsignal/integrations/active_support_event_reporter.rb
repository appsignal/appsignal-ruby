# frozen_string_literal: true

module Appsignal
  module Integrations
    # @!visibility private
    module ActiveSupportEventReporter
      class Subscriber
        def initialize
          @logger = Appsignal::Logger.new("rails_events")
        end

        def emit(event)
          @logger.info(event[:name], event[:payload])
        end
      end
    end
  end
end
