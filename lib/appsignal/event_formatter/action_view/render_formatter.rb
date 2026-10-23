# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ActionView
      class RenderFormatter < Appsignal::EventFormatter
        BLANK = ""

        def initialize
          super
          @relative_paths = Appsignal::Utils::BoundedCache.new
        end

        def opentelemetry_attributes(_payload)
          Appsignal::OpenTelemetry::Rendering.attributes
        end

        def format(payload)
          # The title is the template's path made relative to the application's
          # root, so a template rendered outside an application gets no title.
          return unless payload[:identifier] && root_path

          [relative_path(payload[:identifier]), nil]
        end

        # The application's root, which a template's path is made relative to.
        #
        # Whether there is an application is decided here, when the event is
        # formatted, rather than when this file is loaded. AppSignal can be
        # required before Rails is, and deciding it at load time would leave
        # every template render in the application without a title.
        def root_path
          return unless defined?(Rails)

          @root_path ||= "#{Rails.root}/"
        end

        private

        def relative_path(path)
          @relative_paths.fetch(path) { path.sub(root_path, BLANK).freeze }
        end
      end
    end
  end
end

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
