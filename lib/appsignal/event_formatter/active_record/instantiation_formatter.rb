# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ActiveRecord
      class InstantiationFormatter < Appsignal::EventFormatter
        register "instantiation.active_record"

        def format(payload)
          [payload[:class_name], nil]
        end
      end
    end
  end
end
