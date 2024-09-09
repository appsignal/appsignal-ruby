# frozen_string_literal: true

module Appsignal
  module CheckIn
    # @api private
    class Event
      class << self
        def new(check_in_type:, identifier:, digest: nil, kind: nil)
          {
            :identifier => identifier,
            :digest => digest,
            :kind => kind,
            :timestamp => Time.now.utc.to_i,
            :check_in_type => check_in_type
          }.compact
        end

        def cron(identifier:, digest:, kind:)
          new(
            :check_in_type => "cron",
            :identifier => identifier,
            :digest => digest,
            :kind => kind
          )
        end

        def heartbeat(identifier:)
          new(
            :check_in_type => "heartbeat",
            :identifier => identifier
          )
        end

        def redundant?(event, other)
          return false if
            other[:check_in_type] != event[:check_in_type] ||
              other[:identifier] != event[:identifier]

          return false if event[:check_in_type] == "cron" && (
            other[:digest] != event[:digest] ||
            other[:kind] != event[:kind]
          )

          return false if
            event[:check_in_type] != "cron" &&
              event[:check_in_type] != "heartbeat"

          true
        end

        def describe(events)
          if events.empty?
            # This shouldn't happen.
            "no check-in events"
          elsif events.length > 1
            "#{events.length} check-in events"
          else
            event = events.first
            if event[:check_in_type] == "cron"
              "cron check-in `#{event[:identifier] || "unknown"}` " \
                "#{event[:kind] || "unknown"} event (digest #{event[:digest] || "unknown"})"
            elsif event[:check_in_type] == "heartbeat"
              "heartbeat check-in `#{event[:identifier] || "unknown"}` event"
            else
              "unknown check-in event"
            end
          end
        end
      end
    end
  end
end
