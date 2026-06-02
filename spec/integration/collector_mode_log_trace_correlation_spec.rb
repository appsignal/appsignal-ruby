if DependencyHelper.ruby_3_1_or_newer?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/trace/v1/trace_service_pb"
  require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

  describe "AppSignal collector mode log/trace correlation" do
    before { OTLPCollectorServer.clear }

    it "stamps log records with the trace_id and span_id of the active span" do
      runner = Runner.new("collector_mode_log_trace_correlation",
        :env => OTLPCollectorServer.env)
      runner.run

      trace_req = OTLPCollectorServer.listen_to("/v1/traces")
      trace_msg = Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
        .decode(trace_req[:body])

      log_req = OTLPCollectorServer.listen_to("/v1/logs")
      log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
        .decode(log_req[:body])

      spans = trace_msg.resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
      root = spans.find { |s| s.parent_span_id.empty? }
      event = spans.find { |s| s.name == "test.event" }
      expect(root).not_to be_nil
      expect(event).not_to be_nil
      expect(event.parent_span_id).to eq(root.span_id)

      logs_by_body = log_msg.resource_logs
        .flat_map { |rl| rl.scope_logs.flat_map(&:log_records) }
        .to_h { |lr| [lr.body.string_value, lr] }

      expect(logs_by_body.keys).to match_array(["before event", "inside event", "after event"])

      # Logs emitted outside any event span carry the root span's ids.
      expect(logs_by_body["before event"].trace_id).to eq(root.trace_id)
      expect(logs_by_body["before event"].span_id).to eq(root.span_id)
      expect(logs_by_body["after event"].trace_id).to eq(root.trace_id)
      expect(logs_by_body["after event"].span_id).to eq(root.span_id)

      # The log emitted inside `instrument` carries the event span's ids.
      expect(logs_by_body["inside event"].trace_id).to eq(event.trace_id)
      expect(logs_by_body["inside event"].span_id).to eq(event.span_id)
    end
  end
end
