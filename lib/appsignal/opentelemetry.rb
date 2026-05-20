# frozen_string_literal: true

require "appsignal/opentelemetry/attributes"

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
        # The OTel Ruby SDK exposes no programmatic knob for the default
        # aggregation temporality; this env var is the only way to set
        # it. We pick `:delta` to match the Python integration. (Note:
        # the Ruby SDK keeps `UpDownCounter` cumulative regardless of
        # this preference, per the OTel spec.)
        ENV["OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"] ||= "delta"

        require "opentelemetry/sdk"
        require "opentelemetry/exporter/otlp"
        require "opentelemetry-metrics-sdk"
        require "opentelemetry-exporter-otlp-metrics"
        require "opentelemetry-logs-sdk"
        require "opentelemetry-exporter-otlp-logs"

        endpoint = config[:collector_endpoint].to_s.sub(%r{/+\z}, "")
        # Merge with the SDK's default resource so all three signal types
        # carry the same `telemetry.sdk.*` and `process.*` attributes that
        # `SDK.configure` would have added on its own. `MeterProvider` and
        # `LoggerProvider` take a `resource:` kwarg that replaces (not
        # merges), so we do the merge ourselves and use the same merged
        # resource for the tracer provider to keep all three in sync.
        resource = ::OpenTelemetry::SDK::Resources::Resource.default.merge(build_resource(config))

        ::OpenTelemetry::SDK.configure do |c|
          c.resource = resource
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
        ::OpenTelemetry.meter_provider =
          ::OpenTelemetry::SDK::Metrics::MeterProvider.new(:resource => resource)
        ::OpenTelemetry.meter_provider.add_metric_reader(
          ::OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(
            :exporter => ::OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new(
              :endpoint => "#{endpoint}/v1/metrics"
            )
          )
        )

        ::OpenTelemetry.logger_provider =
          ::OpenTelemetry::SDK::Logs::LoggerProvider.new(:resource => resource)
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

      # Build the OpenTelemetry Resource that carries AppSignal config to the
      # collector. Attributes whose underlying option is nil or an empty array
      # are omitted so the collector applies its own defaults.
      def build_resource(config)
        revision = config[:revision].to_s.empty? ? "unknown" : config[:revision]
        service_name = config[:service_name].to_s.empty? ? "unknown" : config[:service_name]
        host_name = config[:hostname].to_s.empty? ? "unknown" : config[:hostname]

        attrs = {
          "appsignal.config.name" => config[:name],
          "appsignal.config.environment" => config.env,
          "appsignal.config.push_api_key" => config[:push_api_key],
          "appsignal.config.revision" => revision,
          "appsignal.config.language_integration" => "ruby",
          "service.name" => service_name,
          "host.name" => host_name,
          "appsignal.service.process_id" => Process.pid,
          "appsignal.config.filter_attributes" => config[:filter_attributes],
          "appsignal.config.filter_function_parameters" => config[:filter_function_parameters],
          "appsignal.config.filter_request_query_parameters" =>
            config[:filter_request_query_parameters],
          "appsignal.config.filter_request_payload" => config[:filter_request_payload],
          "appsignal.config.filter_request_session_data" => config[:filter_session_data],
          "appsignal.config.ignore_actions" => config[:ignore_actions],
          "appsignal.config.ignore_errors" => config[:ignore_errors],
          "appsignal.config.ignore_namespaces" => config[:ignore_namespaces],
          "appsignal.config.response_headers" => config[:response_headers],
          "appsignal.config.request_headers" => config[:request_headers],
          "appsignal.config.send_function_parameters" => config[:send_function_parameters],
          "appsignal.config.send_request_query_parameters" =>
            config[:send_request_query_parameters],
          "appsignal.config.send_request_payload" => config[:send_request_payload],
          "appsignal.config.send_request_session_data" => config[:send_session_data]
        }
        attrs.reject! { |_, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }
        ::OpenTelemetry::SDK::Resources::Resource.create(attrs)
      end
    end
  end
end
