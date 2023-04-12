# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @api private
    module ActionView
      class RenderFormatter
        BLANK = ""

        attr_reader :root_path

        def initialize
          @root_path = "#{Rails.root}/".freeze
        end

        def format(payload)
          return nil unless payload[:identifier]

          [payload[:identifier].sub(root_path, BLANK), nil]
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
