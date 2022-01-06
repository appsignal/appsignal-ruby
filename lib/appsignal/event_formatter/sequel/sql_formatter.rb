# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module Sequel
      # Compatability with the sequel-rails gem.
      # The sequel-rails gem adds its own ActiveSupport::Notifications events
      # that conflict with our own sequel instrumentor. Without this event
      # formatter the sequel-rails events are recorded without the SQL query
      # that's being executed.
      class SqlFormatter
        def format(payload)
          [payload[:name].to_s, payload[:sql], SQL_BODY_FORMAT]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "sql.sequel",
  Appsignal::EventFormatter::Sequel::SqlFormatter
)
