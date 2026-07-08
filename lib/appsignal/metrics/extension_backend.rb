# frozen_string_literal: true

module Appsignal
  module Metrics
    # @!visibility private
    #
    # Routes custom metric helper calls through the AppSignal C-extension,
    # which forwards them to the agent. This is the default backend used
    # when collector mode is not active.
    module ExtensionBackend
      class << self
        def set_gauge(name, value, tags)
          Appsignal::Extension.set_gauge(
            name.to_s,
            value.to_f,
            Appsignal::Utils::Data.generate(tags)
          )
        rescue RangeError
          Appsignal.internal_logger
            .warn("The gauge value '#{value}' for metric '#{name}' is too big")
        end

        def increment_counter(name, value, tags)
          Appsignal::Extension.increment_counter(
            name.to_s,
            value.to_f,
            Appsignal::Utils::Data.generate(tags)
          )
        rescue RangeError
          Appsignal.internal_logger
            .warn("The counter value '#{value}' for metric '#{name}' is too big")
        end

        def add_distribution_value(name, value, tags)
          Appsignal::Extension.add_distribution_value(
            name.to_s,
            value.to_f,
            Appsignal::Utils::Data.generate(tags)
          )
        rescue RangeError
          Appsignal.internal_logger
            .warn("The distribution value '#{value}' for metric '#{name}' is too big")
        end
      end
    end
  end
end
