# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ViewComponent
      class RenderFormatter
        BLANK = ""

        attr_reader :root_path

        def initialize
          @root_path = "#{Rails.root}/"
        end

        def format(payload)
          [payload[:name], payload[:identifier].sub(@root_path, BLANK)]
        end
      end
    end
  end
end

if defined?(Rails) && defined?(ViewComponent)
  Appsignal::EventFormatter.register(
    "render.view_component",
    Appsignal::EventFormatter::ViewComponent::RenderFormatter
  )
  Appsignal::EventFormatter.register(
    "!render.view_component",
    Appsignal::EventFormatter::ViewComponent::RenderFormatter
  )
end
