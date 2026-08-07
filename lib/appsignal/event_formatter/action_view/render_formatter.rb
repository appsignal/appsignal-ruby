# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ActionView
      class RenderFormatter < Appsignal::EventFormatter
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
  # Action View reports the template's path for these two as well, so they are
  # titled the same way. A collection reports the partial it rendered for each
  # item, and a layout reports itself.
  Appsignal::EventFormatter.register(
    "render_collection.action_view",
    Appsignal::EventFormatter::ActionView::RenderFormatter
  )
  Appsignal::EventFormatter.register(
    "render_layout.action_view",
    Appsignal::EventFormatter::ActionView::RenderFormatter
  )
end
