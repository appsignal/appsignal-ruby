module Appsignal
  class EventFormatter
    module ActiveRecord
      class InstantiationFormatter < Appsignal::EventFormatter
        register 'instantiation.active_record'

        def format(payload)
          [payload[:class_name], nil]
        end
      end
    end
  end
end
