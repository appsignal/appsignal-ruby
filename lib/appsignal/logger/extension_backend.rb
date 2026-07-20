# frozen_string_literal: true

module Appsignal
  class Logger < ::Logger
    # @!visibility private
    #
    # Routes Appsignal::Logger emits through the AppSignal C-extension,
    # which forwards them to the agent. This is the default backend used
    # when collector mode is not active.
    module ExtensionBackend
      class << self
        def emit(group, severity, format, message, attributes)
          Appsignal::Extension.log(
            group,
            SEVERITY_MAP.fetch(severity, 0),
            format,
            message,
            Appsignal::Utils::Data.generate(attributes)
          )
        end
      end
    end
  end
end
