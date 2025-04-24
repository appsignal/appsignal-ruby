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

        def deduplicate_cron!(events) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
          # Remove redundant cron check-in events from the given list of events.
          # This is done by removing redundant *pairs* of events -- that is,
          # for each identifier, only send one complete pair of start and
          # finish events. Remove all other complete pairs of start and finish
          # events for that identifier, but keep any other start or finish events
          # that don't have a matching pair.
          #
          # Note that this method assumes that the events in this list have already
          # been rejected based on `Event.redundant?`, so we don't check to remove
          # check-in events that are functionally identical.
          start_digests = Hash.new { |h, k| h[k] = Set.new }
          finish_digests = Hash.new { |h, k| h[k] = Set.new }
          complete_digests = Hash.new { |h, k| h[k] = Set.new }
          keep_digest = {}

          # Compute a list of complete digests for each identifier, that is, digests
          # for which both a start and finish cron check-in event exist. Store the
          # last seen digest for each identifier as the one to keep.
          events.each do |event|
            if event[:check_in_type] == "cron"
              if event[:kind] == "start"
                start_digests[event[:identifier]] << event[:digest]
                if finish_digests[event[:identifier]].include?(event[:digest])
                  complete_digests[event[:identifier]] << event[:digest]
                  keep_digest[event[:identifier]] = event[:digest]
                end
              elsif event[:kind] == "finish"
                finish_digests[event[:identifier]] << event[:digest]
                if start_digests[event[:identifier]].include?(event[:digest])
                  complete_digests[event[:identifier]] << event[:digest]
                  keep_digest[event[:identifier]] = event[:digest]
                end
              end
            end
          end

          start_digests = nil
          finish_digests = nil

          events.reject! do |event|
            # Do not remove events that are not cron check-in events or that
            # have an unknown kind.
            return false unless
              event[:check_in_type] == "cron" && (
                event[:kind] == "start" ||
                event[:kind] == "finish")

            # Remove any event that is part of a complete digest pair, except
            # for the one digest that should be kept.
            keep_digest[event[:identifier]] != event[:digest] &&
              complete_digests[event[:identifier]].include?(event[:digest])
          end
        end
      end
    end
  end
end
