# frozen_string_literal: true

module Appsignal
  class EventFormatter
    # @!visibility private
    module ViewComponent
      class RenderFormatter < Appsignal::EventFormatter
        BLANK = ""

        def opentelemetry_attributes(_payload)
          Appsignal::OpenTelemetry::Rendering.attributes
        end

        def format(payload)
          # The body is the component's path made relative to the application's
          # root, so a component rendered outside an application gets no title
          # and no body.
          return unless root_path

          [payload[:name], payload[:identifier].sub(root_path, BLANK)]
        end

        # The application's root, which a component's path is made relative to.
        #
        # Whether there is an application is decided here, when the event is
        # formatted, rather than when this file is loaded. AppSignal can be
        # required before Rails is, and deciding it at load time would leave
        # every component render in the application without a title.
        def root_path
          return unless defined?(Rails)

          @root_path ||= "#{Rails.root}/"
        end
      end
    end
  end
end

Appsignal::EventFormatter.register(
  "render.view_component",
  Appsignal::EventFormatter::ViewComponent::RenderFormatter
)
