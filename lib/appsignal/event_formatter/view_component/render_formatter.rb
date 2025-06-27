# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ViewComponent
      class RenderFormatter
        BLANK = ""

        def format(payload)
          [payload[:name], payload[:identifier].sub(root_path, BLANK)]
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
    "render.view_component",
    Appsignal::EventFormatter::ViewComponent::RenderFormatter
  )
  Appsignal::EventFormatter.register(
    "!render.view_component",
    Appsignal::EventFormatter::ViewComponent::RenderFormatter
  )
end
