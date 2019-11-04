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
        Appsignal.logger
          .warn("Gauge value #{value} for key '#{key}' is too big")
      end

      def set_host_gauge(key, value)
        Appsignal::Extension.set_host_gauge(key.to_s, value.to_f)
      rescue RangeError
        Appsignal.logger
          .warn("Host gauge value #{value} for key '#{key}' is too big")
      end

      def set_process_gauge(key, value)
        Appsignal::Extension.set_process_gauge(key.to_s, value.to_f)
      rescue RangeError
        Appsignal.logger
          .warn("Process gauge value #{value} for key '#{key}' is too big")
      end

      def increment_counter(key, value = 1.0, tags = {})
        Appsignal::Extension.increment_counter(
          key.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.logger
          .warn("Counter value #{value} for key '#{key}' is too big")
      end

      def add_distribution_value(key, value, tags = {})
        Appsignal::Extension.add_distribution_value(
          key.to_s,
          value.to_f,
          Appsignal::Utils::Data.generate(tags)
        )
      rescue RangeError
        Appsignal.logger
          .warn("Distribution value #{value} for key '#{key}' is too big")
      end
    end
  end
end
