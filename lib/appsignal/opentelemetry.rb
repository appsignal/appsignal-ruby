# frozen_string_literal: true

module Appsignal
  # @!visibility private
  module OpenTelemetry
    class << self
      # Configure the global OpenTelemetry SDK to export OTLP/HTTP protobuf to
      # the collector endpoint defined in `config[:collector_endpoint]`.
      #
      # Lazily requires the OpenTelemetry SDK and OTLP exporter gems so that
      # users not in collector mode do not pay the load cost.
      def configure(config)
        require "opentelemetry/sdk"
        require "opentelemetry/exporter/otlp"
        require "opentelemetry-metrics-sdk"
        require "opentelemetry-exporter-otlp-metrics"
        require "opentelemetry-logs-sdk"
        require "opentelemetry-exporter-otlp-logs"

        endpoint = config[:collector_endpoint].to_s.sub(%r{/+\z}, "")
        service_name = config[:name].to_s.empty? ? "unknown" : config[:name]

        ::OpenTelemetry::SDK.configure do |c|
          c.service_name = service_name
          c.add_span_processor(
            ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
              ::OpenTelemetry::Exporter::OTLP::Exporter.new(
                :endpoint => "#{endpoint}/v1/traces"
              )
            )
          )
        end

        # Wrap the OTLP MetricsExporter in a PeriodicMetricReader so that
        # `MeterProvider#force_flush` actually triggers an export. The OTLP
        # exporter itself is also a MetricReader but its inherited
        # `force_flush` is a no-op.
        ::OpenTelemetry.meter_provider = ::OpenTelemetry::SDK::Metrics::MeterProvider.new
        ::OpenTelemetry.meter_provider.add_metric_reader(
          ::OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
            :exporter => ::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new(
              :endpoint => "#{endpoint}/v1/metrics"
            )
          )
        )

        ::OpenTelemetry.logger_provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new
        ::OpenTelemetry.logger_provider.add_log_record_processor(
          ::OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
            ::OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
              :endpoint => "#{endpoint}/v1/logs"
            )
          )
        )
      rescue LoadError => e
        Appsignal::Utils::StdoutAndLoggerMessage.error(
          "Cannot configure OpenTelemetry SDK for collector mode: #{e.class}: #{e.message}"
        )
      rescue => e
        Appsignal::Utils::StdoutAndLoggerMessage.error(
          "Error configuring OpenTelemetry SDK for collector mode: " \
            "#{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
        )
      end
    end
  end
end
