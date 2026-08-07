# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # Registered for an event that a dedicated AppSignal integration already
    # records with richer semantics. The generic instrumentation paths ask the
    # registry whether to record an event, so registering this for an event
    # name is how that integration claims it.
    #
    # @!visibility private
    class RecordedElsewhere < Appsignal::EventFormatter
      def record?
        false
      end
    end
  end
end
