# frozen_string_literal: true

module Appsignal
  module OpenTelemetry
    # @!visibility private
    #
    # Builds the OpenTelemetry attributes that describe an event as template
    # rendering.
    #
    # Rendering a template has no semantic convention to describe it, so these
    # events say which group they belong to directly. The trace timeline reads
    # `appsignal.group` before it looks at any convention attribute, and
    # "render" is the group it shows as "Templating".
    module Rendering
      GROUP_ATTRIBUTE = "appsignal.group"
      GROUP = "render"

      ATTRIBUTES = { GROUP_ATTRIBUTE => GROUP }.freeze

      class << self
        # The attributes describing an event as template rendering, as a Hash
        # to pass to `add_opentelemetry_attributes`.
        def attributes
          ATTRIBUTES
        end
      end
    end
  end
end
