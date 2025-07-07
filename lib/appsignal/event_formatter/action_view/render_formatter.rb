# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ActionView
      class RenderFormatter
        BLANK = ""

        def format(payload)
          return nil unless payload[:identifier]

          [payload[:identifier].sub(root_path, BLANK), nil]
        end

        def root_path
          @root_path ||= "#{Rails.root}/"
        end
      end
    end
  end
end

if defined?(Rails)
  Appsignal::EventFormatter.register(
    "render_partial.action_view",
    Appsignal::EventFormatter::ActionView::RenderFormatter
  )
  Appsignal::EventFormatter.register(
    "render_template.action_view",
    Appsignal::EventFormatter::ActionView::RenderFormatter
  )
end
