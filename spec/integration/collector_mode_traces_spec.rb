if DependencyHelper.ruby_3_1_or_newer?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/trace/v1/trace_service_pb"

  describe "AppSignal collector mode trace API" do
    before { OTLPCollectorServer.clear }

    it "emits OTLP spans for Appsignal.monitor with nested Appsignal.instrument" do
      runner = Runner.new("collector_mode_traces", :env => OTLPCollectorServer.env)
      runner.run

      trace_req = OTLPCollectorServer.listen_to("/v1/traces")
      trace_msg = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
        .decode(trace_req[:body])

      spans = trace_msg.resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
      by_name = spans.to_h { |s| [s.name, s] }

      # Root span: SERVER kind from `monitor` (http_request namespace), no parent.
      root = spans.find { |s| s.parent_span_id.empty? }
      expect(root).not_to be_nil
      expect(root.kind).to eq(:SPAN_KIND_SERVER)

      # Event spans for each instrumented block are present.
      expect(by_name.keys).to include("active_record.sql", "template.render", "partial.render")

      # Nested instrument calls produce a parent/child chain rooted at the monitor span.
      expect(by_name["partial.render"].parent_span_id).to eq(by_name["template.render"].span_id)
      expect(by_name["template.render"].parent_span_id).to eq(root.span_id)
      expect(by_name["active_record.sql"].parent_span_id).to eq(root.span_id)

      # All spans share one trace id.
      expect(spans.map(&:trace_id).uniq.size).to eq(1)

      # SQL formatter applied at the OTel backend: body becomes `db.query.text` and
      # `db.system.name` is set so the collector can sanitize.
      sql = by_name["active_record.sql"]
      expect(attribute_value(sql, "db.query.text")).to eq("SELECT * FROM users")
      expect(attribute_value(sql, "db.system.name")).to eq("other_sql")
    end

    def attribute_value(span, key)
      pair = span.attributes.find { |attr| attr.key == key }
      pair&.value&.string_value
    end
  end
end
