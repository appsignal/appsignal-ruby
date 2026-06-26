if DependencyHelper.opentelemetry_present?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/trace/v1/trace_service_pb"

  describe "AppSignal collector mode mixing OTel and AppSignal APIs" do
    before { OTLPCollectorServer.clear }

    it "nests instrument and monitor spans correctly relative to OTel context" do
      runner = Runner.new("collector_mode_mixed_api", :env => OTLPCollectorServer.env)
      runner.run

      trace_req = OTLPCollectorServer.listen_to("/v1/traces")
      trace_msg = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
        .decode(trace_req[:body])

      spans = trace_msg.resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
      by_name = spans.to_h { |s| [s.name, s] }

      outer = by_name.fetch("outer.otel")
      # `Appsignal.monitor` renames its root span to the action, so look it
      # up by SpanKind (SERVER is the subtrace root the collector keys on)
      # rather than by name.
      monitor_root = spans.find { |s| s.kind == :SPAN_KIND_SERVER }
      expect(monitor_root).not_to be_nil
      event_with_otel_child = by_name.fetch("event.with.otel.child")
      inner_otel = by_name.fetch("inner.otel.inside_instrument")
      manual_otel = by_name.fetch("manual.otel.in_monitor")
      event_under_manual = by_name.fetch("event.under.manual.otel")

      # Appsignal.monitor ignores the ambient OTel context and starts a
      # fresh trace.
      expect(monitor_root.parent_span_id).to be_empty
      expect(monitor_root.trace_id).not_to eq(outer.trace_id)

      # Events created via Appsignal.instrument nest under whichever
      # span is current at the time -- the monitor root in the simple
      # case.
      expect(event_with_otel_child.parent_span_id).to eq(monitor_root.span_id)
      expect(event_with_otel_child.trace_id).to eq(monitor_root.trace_id)

      # A raw OTel span created inside an Appsignal.instrument block is
      # a child of the event span.
      expect(inner_otel.parent_span_id).to eq(event_with_otel_child.span_id)
      expect(inner_otel.trace_id).to eq(monitor_root.trace_id)

      # In reverse: when a raw OTel span is current, an
      # Appsignal.instrument inside it nests under that OTel span
      # (not under the monitor root directly).
      expect(manual_otel.parent_span_id).to eq(monitor_root.span_id)
      expect(event_under_manual.parent_span_id).to eq(manual_otel.span_id)
      expect(event_under_manual.trace_id).to eq(monitor_root.trace_id)
    end
  end
end
