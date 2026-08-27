# frozen_string_literal: true

require "appsignal/opentelemetry/attributes"
require "appsignal/opentelemetry/dependencies"
require "appsignal/opentelemetry/error_type"
require "appsignal/opentelemetry/http_client_request"
require "appsignal/opentelemetry/http_method"
require "appsignal/opentelemetry/http_response"
require "appsignal/opentelemetry/http_server_request"
require "appsignal/opentelemetry/messaging"
require "appsignal/opentelemetry/rendering"
require "appsignal/opentelemetry/sql_db_system"

module Appsignal
  # @!visibility private
  module OpenTelemetry
    # The carrier key that marks an Active Job job as one of a batch. Not a W3C
    # trace context header, and deliberately not named like one, so no
    # propagator reads it as one.
    ACTIVE_JOB_BATCH_HEADER = "appsignal-batch"

    class << self
      # Configure the global OpenTelemetry SDK to export OTLP/HTTP protobuf to
      # the collector endpoint in `config[:collector_endpoint]`.
      #
      # The SDK and exporter gems are required lazily, so an application not in
      # collector mode does not pay the load cost. Sets `@started`, which
      # {.started?} reads to decide whether to route through the OTel backends.
      def configure(config)
        # The OTel Ruby SDK exposes no programmatic knob for the default
        # aggregation temporality; this env var is the only way to set
        # it. We pick `:delta` to match the Python integration. (Note:
        # the Ruby SDK keeps `UpDownCounter` cumulative regardless of
        # this preference, per the OTel spec.)
        ENV["OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE"] ||= "delta"

        # With the metrics and logs SDK gems loaded, `SDK.configure` below
        # auto-installs a metrics reader and a log processor from these env vars,
        # each with its own background thread. Both providers are replaced right
        # after, which would leave those threads running and unreachable by any
        # shutdown. Set unconditionally, so a user-set "otlp" cannot slip past
        # and reintroduce them.
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
      # job hash, ...) with the configured propagator, so a downstream service
      # joins the same trace.
      #
      # A no-op unless the SDK has booted. The carrier is injected from whatever
      # span is current at call time, which inside an `Appsignal.instrument`
      # block is the event's own span.
      def inject_context(carrier)
        if_started do
          ::OpenTelemetry.propagation.inject(carrier)
        end
      end

      # Read the trace context off an incoming Rack request env using the
      # globally configured propagator, so an AppSignal transaction created for
      # the request can continue the upstream trace. Returns an
      # `OpenTelemetry::Context` (its current span is the remote parent), or
      # `nil` when the SDK has not booted -- outside collector mode there is
      # nothing to continue. `rack_env_getter` reads the `HTTP_*`-mangled header
      # names Rack puts in the env.
      def extract_rack_context(env)
        if_started do
          # Extract onto an empty context, not `Context.current`. The W3C
          # extractor returns its base context unchanged when the carrier has no
          # `traceparent`, so a request with no incoming context would inherit
          # whatever span is ambient on the fiber. Starting empty means "no
          # carrier" yields no parent, and the transaction starts its own trace.
          ::OpenTelemetry.propagation.extract(
            env,
            :context => ::OpenTelemetry::Context.empty,
            :getter => ::OpenTelemetry::Common::Propagation.rack_env_getter
          )
        end
      end

      # Read the trace context off an incoming background job hash, so the
      # transaction can link back to the enqueuer. Returns an
      # `OpenTelemetry::Context`, or `nil` when the SDK has not booted.
      #
      # Reads both carriers a job can arrive with: top-level `traceparent` and
      # `tracestate` keys, as OpenTelemetry's Sidekiq instrumentation injects
      # them, and a nested `__otel_headers`, as its Active Job one does. Active
      # Job puts that through its argument serializer, so it can arrive as an
      # array of pairs rather than a hash. The nested keys win, being the more
      # specific layer.
      def extract_job_context(item)
        if_started do
          carrier = item
          nested = otel_headers_hash(item["__otel_headers"])
          carrier = item.merge(nested) if nested
          # Extract onto an empty context rather than the default
          # `Context.current`, for the same reason as `extract_rack_context`:
          # a job with no injected trace context must not inherit an ambient
          # span left on the fiber. Otherwise the job's transaction would link
          # back to an unrelated leaked span instead of standing on its own.
          ::OpenTelemetry.propagation.extract(
            carrier,
            :context => ::OpenTelemetry::Context.empty
          )
        end
      end

      # Read the trace context off the serialized Active Job job data that a
      # queue adapter's job wraps, so the transaction the adapter creates links
      # back to the enqueuer.
      #
      # Every adapter wraps the job data as the single argument of its own job
      # wrapper, but each keeps it somewhere different, so finding the job data
      # is the adapter integration's business and reading a context out of it is
      # this method's.
      #
      # This is the layer every integration prefers. Active Job owns the job
      # whichever adapter carries it, its carrier survives an adapter that has
      # nowhere of its own to put a header, and it does not compete with the
      # user's own data for a carrier with a hard limit on what fits.
      #
      # Returns `nil` when the SDK has not booted, when this is not Active Job
      # job data, and when the job data carries no usable context. A caller reads
      # that `nil` as "nothing here" and falls back to its own native carrier.
      # That fallback matters twice over: it is where a job enqueued by a service
      # that instruments only the adapter carries its context, and it is the only
      # carrier a job that is not an Active Job job has at all.
      def extract_active_job_context(job_data)
        return unless job_data.is_a?(Hash)

        if_started do
          headers = otel_headers_hash(job_data["__otel_headers"])
          next unless headers

          # Extract onto an empty context, for the same reason as
          # `extract_job_context` above.
          context = ::OpenTelemetry.propagation.extract(
            headers,
            :context => ::OpenTelemetry::Context.empty
          )
          context if remote_span_context(context)
        end
      end

      # Marks an outgoing Active Job carrier as belonging to a batch, so the
      # integration that later performs the job can tell the two enqueue paths
      # apart. Every job in a batch shares the one producer span, and a span can
      # have only one parent, so a batch has to link back rather than parent
      # under it -- and only the enqueue side knows it was a batch.
      #
      # The marker rides in the same carrier as the trace context.
      # `propagation.extract` ignores a key it does not recognise, so it is
      # invisible to every other reader of that carrier, including
      # OpenTelemetry's own Active Job instrumentation.
      #
      # Does nothing to a carrier nothing was injected into. Without a context
      # there is no producer span to link back to, so the marker would have
      # nothing to say.
      def mark_active_job_batch(headers)
        return if headers.empty?

        headers[ACTIVE_JOB_BATCH_HEADER] = "1"
      end

      # Whether Active Job job data says the job was enqueued as part of a batch.
      # An integration reads this to choose between linking the performed job
      # back to the enqueuer and also parenting it under them.
      def active_job_batch?(job_data)
        return false unless job_data.is_a?(Hash)

        headers = otel_headers_hash(job_data["__otel_headers"])
        return false unless headers

        headers[ACTIVE_JOB_BATCH_HEADER] == "1"
      end

      # The remote parent's SpanContext from an incoming OTel context, or `nil`
      # when there is no context or the span in it is invalid.
      #
      # `propagation.extract` returns a context whether or not the carrier held
      # anything, so this is what tells "read a context" apart from "read
      # nothing". A caller that can fall back to another carrier uses it to
      # decide whether to, and a caller that parents or links a span uses it to
      # decide between doing that and starting a plain root span.
      #
      # Only ever called with a context that came from the OpenTelemetry SDK, so
      # it does not gate on the SDK having booted the way the extract methods do.
      def remote_span_context(opentelemetry_context)
        return unless opentelemetry_context

        span_context =
          ::OpenTelemetry::Trace.current_span(opentelemetry_context).context
        span_context if span_context.valid?
      end

      # Run `block` only when the OpenTelemetry SDK has booted (collector mode),
      # returning its result; a no-op returning `nil` otherwise. The block can
      # touch the OTel SDK freely -- it only runs when the SDK is loaded.
      #
      # This is the gate every integration's OTel-specific work goes through, so
      # integration-specific carrier/getter/setter logic lives in the
      # integration rather than as a bespoke helper here.
      def if_started
        return unless started?

        yield
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
      # are omitted so the collector applies its own defaults. The revision,
      # service name and host name are the exception: they fall back to a
      # value here, so they are always sent.
      def build_resource(config)
        revision = config[:revision].to_s.empty? ? "unknown" : config[:revision]
        service_name = config[:service_name].to_s.empty? ? "app" : config[:service_name]
        host_name = config[:hostname].to_s.empty? ? "unknown" : config[:hostname]

        attrs = {
          "appsignal.config.name" => config[:name],
          "appsignal.config.environment" => config.env,
          "appsignal.config.push_api_key" => config[:push_api_key],
          "appsignal.config.revision" => revision,
          "appsignal.config.app_path" => config.root_path&.to_s,
          "appsignal.config.platform" => config[:platform],
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
          "appsignal.config.ignore_logs" => config[:ignore_logs],
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

      # A `__otel_headers` value as a hash carrier, or `nil` when there is no
      # usable one. Active Job puts the headers through its argument serializer,
      # which turns the hash into an array of `[key, value]` pairs, so both
      # shapes arrive. Anything else, including a malformed array, gives `nil`
      # rather than raising on `to_h` inside a job perform.
      def otel_headers_hash(value)
        return value if value.is_a?(Hash)
        return value.to_h if otel_header_pairs?(value)

        nil
      end

      # Whether a `__otel_headers` value is the array-of-`[key, value]`-pairs
      # shape produced by ActiveJob's argument serializer.
      def otel_header_pairs?(value)
        value.is_a?(Array) && value.all? { |pair| pair.is_a?(Array) && pair.size == 2 }
      end

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
        incompatible = incompatible_gems
        return true if incompatible.nil?

        @started = false
        Appsignal::Utils::StdoutAndLoggerMessage.warning(
          collector_gems_warning(incompatible)
        )
        false
      end

      # Builds the warning shown when the OpenTelemetry gems collector mode needs
      # are not all installed at a supported version. `incompatible` describes
      # the gems that are installed but at a version we do not support.
      #
      # The message always recommends the `appsignal-opentelemetry` gem, which
      # installs the whole set. It only lists gems when some are installed at an
      # incompatible version, because that usually means a constraint in the
      # bundle that the gem cannot override on its own.
      def collector_gems_warning(incompatible)
        message =
          "AppSignal collector mode requires a set of OpenTelemetry gems. " \
            "Add the `appsignal-opentelemetry` gem to your bundle to install " \
            "them. The AppSignal agent will be used instead."

        unless incompatible.empty?
          message += "\n\nThese installed OpenTelemetry gems are not compatible " \
            "with this AppSignal version. Update them or remove a version " \
            "constraint:\n"
          message += incompatible.map { |line| "- #{line}" }.join("\n")
        end

        message
      end

      # Checks the installed OpenTelemetry gems against {REQUIRED_GEMS}. Returns
      # `nil` when every required gem is installed at a supported version.
      # Otherwise returns the descriptions of gems that are installed but at a
      # version we do not support. That list is empty when the only problem is
      # that some required gems are not installed at all.
      def incompatible_gems
        missing = false
        incompatible = []

        REQUIRED_GEMS.each do |name, constraints|
          spec = Gem.loaded_specs[name]
          requirement = Gem::Requirement.new(*constraints)

          if spec.nil?
            missing = true
          elsif !requirement.satisfied_by?(spec.version)
            incompatible << "#{name} #{spec.version} (requires #{requirement})"
          end
        end

        return nil if !missing && incompatible.empty?

        incompatible
      end
    end
  end
end
