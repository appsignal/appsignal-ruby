module Appsignal
  module Middleware
    class ActionViewSanitizer
      TARGET_EVENT_CATEGORY = 'action_view'.freeze

      def call(event)
        if event.name.end_with?(TARGET_EVENT_CATEGORY)
          if event.payload[:identifier]
            event.payload[:identifier].gsub!(root_path, '')
          end
        end
      end

      def root_path
        @root_path ||= "#{Rails.root.to_s}/"
      end
    end
  end
end
