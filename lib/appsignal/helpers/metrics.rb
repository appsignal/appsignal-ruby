# frozen_string_literal: true

module Appsignal
  module Helpers
    module Metrics
      def set_gauge(key, value, tags = {})
        Appsignal::Extension.set_gauge(
          key.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("Gauge value #{value} for key '#{key}' is too big")
      end

      def set_host_gauge(_key, _value)
        Appsignal::Utils::DeprecationMessage.message \
          "The `set_host_gauge` method has been deprecated. " \
            "Calling this method has no effect. " \
            "Please remove method call in the following file to remove " \
            "this message.\n#{caller.first}"
      end

      def set_process_gauge(_key, _value)
        Appsignal::Utils::DeprecationMessage.message \
          "The `set_process_gauge` method has been deprecated. " \
            "Calling this method has no effect. " \
            "Please remove method call in the following file to remove " \
            "this message.\n#{caller.first}"
      end

      def increment_counter(key, value = 1.0, tags = {})
        Appsignal::Extension.increment_counter(
          key.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("Counter value #{value} for key '#{key}' is too big")
      end

      def add_distribution_value(key, value, tags = {})
        Appsignal::Extension.add_distribution_value(
          key.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.internal_logger
          .warn("Distribution value #{value} for key '#{key}' is too big")
      end
    end
  end
end
