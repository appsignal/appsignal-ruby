module Appsignal
  class Aggregator
    module Middleware
      class ActionViewSanitizer
        TARGET_EVENT_CATEGORY = 'action_view'.freeze

        def call(event)
          if event.name.end_with?(TARGET_EVENT_CATEGORY)
            identifier = event.payload[:identifier]
            if identifier
              event.payload[:identifier] = identifier.gsub(root_path, '')
            end
          end
          yield
        end

        def root_path
          @root_path ||= "#{Rails.root.to_s}/"
        end
      end
    end
  end
end
