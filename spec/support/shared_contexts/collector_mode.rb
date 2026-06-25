# frozen_string_literal: true

# The OpenTelemetry gems are optional (not gemspec dependencies), so only
# require them when present. This shared context is auto-loaded for every run,
# but its OTel references live in lazy `let`/`before`/`after` blocks that only
# run for `:collector_mode`-tagged examples — and those specs are themselves
# guarded on `opentelemetry_present?`, so they don't load without the gems.
if DependencyHelper.opentelemetry_present?
  require "opentelemetry/sdk"
  require "opentelemetry-metrics-sdk"
  require "opentelemetry-logs-sdk"
end

RSpec.shared_context "collector mode", :collector_mode do
  let(:span_exporter) { ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer_provider) do
    provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(
      ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(span_exporter)
    )
    provider
  end

  let(:metric_exporter) { ::OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new }
  let(:meter_provider) do
    provider = ::OpenTelemetry::SDK::Metrics::MeterProvider.new
    provider.add_metric_reader(metric_exporter)
    provider
  end

  let(:log_exporter) { ::OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new }
  let(:logger_provider) do
    provider = ::OpenTelemetry::SDK::Logs::LoggerProvider.new
    provider.add_log_record_processor(
      ::OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(log_exporter)
    )
    provider
  end

  # Dual-mode start principle: mode is global state, so the agent is NOT
  # started in a `before` here -- that fought with ad-hoc `start_agent` calls
  # with fragile ordering. Each `:collector_mode` example calls
  # `start_collector_agent` itself in its body (the `it_in_both_modes` helper
  # does this for its shared body). This context provides the in-memory
  # providers, the `start_collector_agent` helper, the read-back helpers, and
  # the teardown below.
  after do
    # `clear_current_transaction!` in spec_helper clears the thread-local but
    # not the attached OTel context. `complete_current!` does both.
    Appsignal::Transaction.complete_current!
    # Shut down whatever OTel SDK is current at teardown. Usually that's
    # the threadless in-memory providers (a near no-op), but examples that
    # boot AppSignal again themselves leave real providers behind, whose
    # background threads would otherwise accumulate across the suite. The
    # targeted shutdown, not `Appsignal.stop`: stop's `Extension.stop`
    # takes ~2 seconds per call, which across every collector-mode example
    # adds minutes to the suite. Runs before the global
    # `Appsignal::OpenTelemetry.reset!` hook, so the `started?` gate inside
    # the shutdown still passes.
    Appsignal::OpenTelemetry.shutdown
    # Booting the SDK installs the global W3C propagator as a side effect, and
    # nothing ever resets it. Left in place it leaks to every later example, so
    # an unrelated spec can silently pass on a propagator this example happened
    # to install. Reset it to the API default so collector-mode examples can't
    # leak trace propagation into the rest of the suite.
    ::OpenTelemetry.propagation =
      ::OpenTelemetry::Context::Propagation::NoopTextMapPropagator.new
  end

  # Boots the agent in collector mode and swaps in the in-memory OTel providers.
  # Called explicitly from each collector-mode example body.
  #
  # Examples can define a `start_agent_args` `let` to pass `:env`/`:options`; the
  # `collector_endpoint` is always merged into the options so collector mode
  # stays enabled. Guarded with `defined?` rather than a default `let`, because
  # an included shared context's `let` would take precedence over the example
  # group's own `let` override.
  def start_collector_agent
    args = (defined?(start_agent_args) ? start_agent_args : {}).dup
    args[:options] = { :collector_endpoint => OTLPCollectorServer.endpoint }
      .merge(args[:options] || {})
    start_agent(**args)
    # `Appsignal.start` booted a full OTel SDK whose providers each carry a
    # background export thread (batch span and log processors, periodic
    # metric reader). Shut it down before the swaps below: after the swap
    # the booted providers are unreachable and their threads would leak
    # across examples.
    Appsignal::OpenTelemetry.shutdown
    # Swap in the in-memory providers so the test can read spans/metrics/
    # logs back, and reset the metrics/logger backends so their cached
    # meter/logger re-resolve against these providers on the next emit.
    ::OpenTelemetry.tracer_provider = tracer_provider
    ::OpenTelemetry.meter_provider = meter_provider
    ::OpenTelemetry.logger_provider = logger_provider
    Appsignal::Metrics::OpenTelemetryBackend.reset!
    Appsignal::Logger::OpenTelemetryBackend.reset!
  end

  def root_span
    span_exporter.finished_spans.find { |s| [:server, :consumer].include?(s.kind) }
  end

  def event_spans
    span_exporter.finished_spans.reject { |s| [:server, :consumer].include?(s.kind) }
  end

  # The OpenTelemetry `exception` events recorded across all finished spans
  # (errors attach to the span that was current when they were set, which may
  # be the root span or an event span).
  def exception_events
    span_exporter.finished_spans.flat_map { |span| Array(span.events) }.select do |event|
      event.name == "exception"
    end
  end

  # Pull the current metric snapshots from the in-memory reader. The OTLP
  # exporter is also a reader, so a `pull` collects everything recorded so far.
  def metric_snapshots
    metric_exporter.pull
    snapshots = metric_exporter.metric_snapshots.dup
    metric_exporter.reset
    snapshots
  end

  def metric_snapshot(name)
    metric_snapshots.find { |snapshot| snapshot.name == name }
  end

  def log_records
    log_exporter.emitted_log_records
  end
end

RSpec.configure do |config|
  config.include_context "collector mode", :collector_mode
end
