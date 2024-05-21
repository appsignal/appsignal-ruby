# frozen_string_literal: true

module Appsignal
  module Helpers
    module Heartbeats
      def heartbeat(name)
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
  end
end
