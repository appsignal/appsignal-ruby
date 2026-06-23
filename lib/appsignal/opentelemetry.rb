# frozen_string_literal: true

require "appsignal/opentelemetry/attributes"
require "appsignal/opentelemetry/dependencies"

module Appsignal
  # @!visibility private
  module OpenTelemetry
    class << self
      # Configure the global OpenTelemetry SDK to export OTLP/HTTP protobuf to
      # the collector endpoint defined in `config[:collector_endpoint]`.
      #
      # Lazily requires the OpenTelemetry SDK and OTLP exporter gems so that
      # users not in collector mode do not pay the load cost.
      #
      # Sets `@started` to `true` on success, `false` if the SDK gems can't be
      # loaded or any other error occurs. Callers can read this via
      # {.started?} to decide whether to route through the OTel backends.
      def configure(config)
        # The OTel Ruby SDK exposes no programmatic knob for the default
        # aggregation temporality; this env var is the only way to set
        # it. We pick `:delta` to match the Python integration. (Note:
        # the Ruby SDK keeps `UpDownCounter` cumulative regardless of
        # this preference, per the OTel spec.)
        ENV["OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"] ||= "delta"

        # With the metrics and logs SDK gems loaded, `SDK.configure` below
        # auto-installs a metrics reader and a log processor from these env
        # vars (both default to "otlp", pointed at the default OTLP
        # endpoint), each with its own background thread. We replace both
        # providers with our own right after, which would orphan those
        # threads -- unreachable by any shutdown. Suppress the auto-setup;
        # the exporters we build below are the only ones that should run.
        # Set unconditionally: a user-set "otlp" here would otherwise slip
        # past and reintroduce the orphaned threads.
        ENV["OTEL_METRICS_EXPORTER"] = "none"
        ENV["OTEL_LOGS_EXPORTER"] = "none"

        require_sdk_gems

        # The OpenTelemetry gems are optional and installed by the user (not
        # declared in the gemspec). If they're present but older than the
        # versions we support, fall back to the agent rather than booting an
        # SDK that may misbehave (e.g. a metrics SDK without fork hooks).
        return unless required_gem_versions_met?

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

        @started = true
      rescue LoadError => e
        @started = false
        Appsignal::Utils::StdoutAndLoggerMessage.error(
          "Cannot configure OpenTelemetry SDK for collector mode: #{e.class}: #{e.message}"
        )
      rescue => e
        @started = false
        Appsignal::Utils::StdoutAndLoggerMessage.error(
          "Error configuring OpenTelemetry SDK for collector mode: " \
            "#{e.class}: #{e.message}\n#{e.backtrace&.join("\n")}"
        )
      end

      # Whether {.configure} has successfully booted the OpenTelemetry SDK
      # for this process. Returns `false` before {.configure} runs and
      # `false` if it ran but raised.
      def started?
        defined?(@started) ? @started : false
      end

      # Write the current trace context onto an outgoing carrier (HTTP request,
      # job hash, ...) using the globally configured propagator (W3C
      # TraceContext + baggage). Called by integrations on the emit side so a
      # downstream service joins the same trace.
      #
      # No-op unless the SDK has booted ({.started?}); outside collector mode
      # there is no context to propagate. The carrier is injected from whatever
      # span is current at call time -- inside an `Appsignal.instrument` block
      # that is the AppSignal event span, so the written `traceparent` reflects
      # it.
      def inject_context(carrier)
        return unless started?

        ::OpenTelemetry.propagation.inject(carrier)
      end

      # Read the trace context off an incoming Rack request env using the
      # globally configured propagator, so an AppSignal transaction created for
      # the request can continue the upstream trace. Returns an
      # `OpenTelemetry::Context` (its current span is the remote parent), or
      # `nil` when the SDK has not booted -- outside collector mode there is
      # nothing to continue. `rack_env_getter` reads the `HTTP_*`-mangled header
      # names Rack puts in the env.
      def extract_rack_context(env)
        return unless started?

        ::OpenTelemetry.propagation.extract(
          env,
          :getter => ::OpenTelemetry::Common::Propagation.rack_env_getter
        )
      end

      # @!visibility private
      #
      # Test-only. Drops the started flag so subsequent tests start from a
      # clean slate; does not touch the global `::OpenTelemetry` providers.
      def reset!
        @started = false
      end

      # Flush and shut down the OpenTelemetry SDK providers booted by
      # {.configure}. Called from `Appsignal.stop` so buffered
      # metrics/logs/spans don't get dropped on exit.
      def shutdown
        return unless started?

        ::OpenTelemetry.tracer_provider&.shutdown
        ::OpenTelemetry.meter_provider&.shutdown
        ::OpenTelemetry.logger_provider&.shutdown
      rescue => e
        Appsignal.internal_logger.error(
          "Error shutting down OpenTelemetry SDK: #{e.class}: #{e.message}"
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

      private

      # The optional OpenTelemetry gems, required lazily so users not in
      # collector mode don't pay the load cost. A missing gem raises LoadError,
      # caught by {.configure}.
      def require_sdk_gems
        require "opentelemetry/sdk"
        require "opentelemetry-common"
        require "opentelemetry/exporter/otlp"
        require "opentelemetry-metrics-sdk"
        require "opentelemetry-exporter-otlp-metrics"
        require "opentelemetry-logs-sdk"
        require "opentelemetry-exporter-otlp-logs"
      end

      # Checks the installed OpenTelemetry gem versions against {REQUIRED_GEMS}.
      # On a shortfall, warns and flags the SDK as not started so the caller
      # falls back to the agent; returns whether all requirements are met.
      def required_gem_versions_met?
        unmet = unmet_gem_requirements
        return true if unmet.empty?

        @started = false
        Appsignal::Utils::StdoutAndLoggerMessage.warning(
          "Cannot enable collector mode: the installed OpenTelemetry gems are " \
            "older than the minimum supported versions (#{unmet.join(", ")}). " \
            "Update them in your Gemfile; the AppSignal agent will be used instead."
        )
        false
      end

      # Descriptions of the OpenTelemetry gems that are missing or older than
      # the minimum version in {REQUIRED_GEMS}. Empty when all are satisfied.
      def unmet_gem_requirements
        REQUIRED_GEMS.filter_map do |name, minimum|
          spec = Gem.loaded_specs[name]
          if spec.nil?
            "#{name} (not installed)"
          elsif spec.version < Gem::Version.new(minimum)
            "#{name} #{spec.version} (requires >= #{minimum})"
          end
        end
      end
    end
  end
end
