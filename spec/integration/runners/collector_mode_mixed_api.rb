PROJECT_ROOT = "../../../".freeze
$LOAD_PATH.unshift(File.expand_path("ext", PROJECT_ROOT))
$LOAD_PATH.unshift(File.expand_path("lib", PROJECT_ROOT))

require "appsignal"

# Name, environment and push API key come from the env vars the Runner
# injects (see `Runner::DEFAULT_ENV`); `Appsignal.start` loads them.
Appsignal.start

tracer = OpenTelemetry.tracer_provider.tracer("integration-test")

# Outer raw OTel span. `Appsignal.monitor` is called while this span is
# current; the monitor's root must NOT inherit this as its parent.
tracer.in_span("outer.otel") do
  Appsignal.monitor(:action => "MonitoredAction") do
    # A raw OTel span created inside an `Appsignal.instrument` block
    # should be a child of the event span.
    Appsignal.instrument("event.with.otel.child") do
      tracer.in_span("inner.otel.inside_instrument") do
        # No body; the span's parentage is what the spec asserts on.
      end
    end

    # In reverse: when a raw OTel span is current, an
    # `Appsignal.instrument` invoked inside it should produce an event
    # span that is a child of that OTel span (not of the monitor root).
    tracer.in_span("manual.otel.in_monitor") do
      Appsignal.instrument("event.under.manual.otel") do
        # No body; the span's parentage is what the spec asserts on.
      end
    end
  end
end

Appsignal.stop("integration test")

puts "DONE"
