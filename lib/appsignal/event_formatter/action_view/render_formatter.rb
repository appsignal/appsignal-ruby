module Appsignal
  class EventFormatter
    module ActionView
      class RenderFormatter < Appsignal::EventFormatter
        register 'render_partial.action_view'
        register 'render_template.action_view'

        BLANK = ''.freeze

        attr_reader :root_path

        def initialize
          @root_path = "#{Rails.root.to_s}/".freeze
        end

        def format(payload)
          return nil unless payload[:identifier]
          [payload[:identifier].sub(root_path, BLANK), nil]
        end
      end
    end
  end
end
