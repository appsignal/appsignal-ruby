# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ActiveRecord
      class InstantiationFormatter
        def format(payload)
          [payload[:class_name], nil]
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "instantiation.active_record",
  Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter
)
