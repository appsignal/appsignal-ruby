if DependencyHelper.opentelemetry_present?
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

      # The "http_request" namespace is converted to "web" on the way out.
      expect(attribute_value(root, "appsignal.namespace")).to eq("web")

      # Event spans for each instrumented block are present. Every event span
      # name leads with the event name. The title-less events keep just that
      # name. The SQL event has a human-readable title ("Find user"), so its
      # name adds the title in parentheses after the event name.
      expect(by_name.keys).to include("template.render", "partial.render")
      sql = by_name["active_record.sql (Find user)"]
      expect(sql).not_to be_nil

      # Nested instrument calls produce a parent/child chain rooted at the monitor span.
      expect(by_name["partial.render"].parent_span_id).to eq(by_name["template.render"].span_id)
      expect(by_name["template.render"].parent_span_id).to eq(root.span_id)
      expect(sql.parent_span_id).to eq(root.span_id)

      # All spans share one trace id.
      expect(spans.map(&:trace_id).uniq.size).to eq(1)

      # SQL formatter applied at the OTel backend: body becomes `db.query.text` and
      # `db.system.name` is set so the collector can sanitize.
      expect(attribute_value(sql, "db.query.text")).to eq("SELECT * FROM users")
      expect(attribute_value(sql, "db.system.name")).to eq("other_sql")

      # A query is an outgoing call to a datastore, so its span is a client
      # span. The runner does not pass a span kind, so this is the default.
      expect(sql.kind).to eq(:SPAN_KIND_CLIENT)

      # Allocation counts: the transaction total on the root span and a per-event
      # count on each event span. The values are real allocations, so assert the
      # wiring (present and non-negative) rather than exact counts. The monitored
      # block always allocates, so the transaction total is positive.
      expect(int_attribute_value(root, "appsignal.transaction_allocation_count")).to be > 0
      expect(int_attribute_value(root, "appsignal.self_allocation_count")).to be >= 0
      expect(int_attribute_value(sql, "appsignal.allocation_count")).to be >= 0
      expect(int_attribute_value(sql, "appsignal.self_allocation_count")).to be >= 0
    end

    context "with invalid UTF-8" do
      # The OTLP exporter encodes each batch to protobuf in one go, and
      # protobuf refuses strings that are not valid UTF-8. One invalid string
      # then costs the whole batch, valid data included. Each example puts
      # invalid UTF-8 in one place a transaction accepts input, and asserts
      # that the valid transaction emitted alongside it, and the data carrying
      # the invalid string, are both exported. The invalid bytes are expected
      # to arrive replaced with U+FFFD.
      let(:replaced) { "caf\u{FFFD}" }
      let(:invalid_action) { "InvalidUtf8Controller#index" }

      {
        "a UTF-8 string with invalid bytes" => "utf8",
        "a binary string with non-ASCII bytes" => "binary"
      }.each do |description, encoding|
        context "as #{description}" do
          let(:encoding) { encoding }

          it "exports a transaction with an invalid action name" do
            run_invalid_utf8_scenario("action")

            spans = exported_spans
            expect(spans.map(&:name)).to include("MyController#index", replaced)
            span = spans.find { |s| s.name == replaced }
            expect(attribute_value(span, "appsignal.action_name")).to eq(replaced)
          end

          it "exports a transaction with an invalid namespace" do
            run_invalid_utf8_scenario("namespace")

            span = exported_invalid_root_span
            expect(attribute_value(span, "appsignal.namespace")).to eq(replaced)
          end

          it "exports a transaction with an invalid metadata value" do
            run_invalid_utf8_scenario("metadata")

            span = exported_invalid_root_span
            expect(attribute_value(span, "appsignal.tag.path")).to eq(replaced)
          end

          it "exports a transaction with an invalid tag value" do
            run_invalid_utf8_scenario("tag_value")

            span = exported_invalid_root_span
            expect(attribute_value(span, "appsignal.tag.invalid_tag")).to eq(replaced)
          end

          it "exports a transaction with an invalid tag key" do
            run_invalid_utf8_scenario("tag_key")

            span = exported_invalid_root_span
            expect(attribute_value(span, "appsignal.tag.#{replaced}")).to eq("value")
          end

          it "exports a transaction with an invalid request header value" do
            run_invalid_utf8_scenario("request_header")

            span = exported_invalid_root_span
            expect(attribute_value(span, "http.request.header.accept")).to eq(replaced)
          end

          it "exports a transaction with an invalid OpenTelemetry attribute value" do
            run_invalid_utf8_scenario("opentelemetry_attribute_value")

            span = exported_invalid_root_span
            expect(attribute_value(span, "invalid.attribute")).to eq(replaced)
          end

          it "exports a transaction with an invalid OpenTelemetry attribute key" do
            run_invalid_utf8_scenario("opentelemetry_attribute_key")

            span = exported_invalid_root_span
            expect(attribute_value(span, replaced)).to eq("value")
          end

          it "exports a transaction with an invalid error message" do
            run_invalid_utf8_scenario("error_message")

            exception = span_event(exported_invalid_root_span, "exception")
            expect(attribute_value(exception, "exception.message")).to eq(replaced)
          end

          it "exports a transaction with an invalid error backtrace" do
            run_invalid_utf8_scenario("error_backtrace")

            exception = span_event(exported_invalid_root_span, "exception")
            expect(attribute_value(exception, "exception.stacktrace")).to eq(replaced)
          end

          it "exports a transaction with an invalid error cause message" do
            run_invalid_utf8_scenario("error_cause_message")

            exception = span_event(exported_invalid_root_span, "exception")
            causes = attribute_value(exception, "appsignal.error_causes")
            expect(causes).not_to be_nil
            expect(JSON.parse(causes).first["message"]).to eq(replaced)
          end

          it "exports a transaction with an invalid breadcrumb message" do
            run_invalid_utf8_scenario("breadcrumb_message")

            breadcrumb = span_event(exported_invalid_root_span, "appsignal.breadcrumb")
            expect(attribute_value(breadcrumb, "message")).to eq(replaced)
          end

          it "exports a transaction with an invalid breadcrumb metadata value" do
            run_invalid_utf8_scenario("breadcrumb_metadata")

            breadcrumb = span_event(exported_invalid_root_span, "appsignal.breadcrumb")
            metadata = attribute_value(breadcrumb, "metadata")
            expect(metadata).not_to be_nil
            expect(JSON.parse(metadata)).to eq("key" => replaced)
          end

          it "exports an event with an invalid name" do
            run_invalid_utf8_scenario("event_name")

            expect(exported_invalid_event_span.name).to eq(replaced)
          end

          it "exports an event with an invalid title" do
            run_invalid_utf8_scenario("event_title")

            expect(exported_invalid_event_span.name).to eq("event.invalid (#{replaced})")
          end

          it "exports an event with an invalid body" do
            run_invalid_utf8_scenario("event_body")

            event = exported_invalid_event_span
            expect(attribute_value(event, "appsignal.body")).to eq(replaced)
          end

          it "exports a SQL event with an invalid query" do
            run_invalid_utf8_scenario("sql_body")

            event = exported_invalid_event_span
            expect(attribute_value(event, "db.query.text")).to eq(replaced)
          end
        end
      end

      def run_invalid_utf8_scenario(scenario)
        runner = Runner.new(
          "collector_mode_traces",
          :env => OTLPCollectorServer.env.merge(
            "INVALID_UTF8_SCENARIO" => scenario,
            "INVALID_UTF8_ENCODING" => encoding
          )
        )
        runner.run
      end

      # The runner has stopped AppSignal and exited by the time this is
      # called, so an exported batch has already arrived. A short timeout is
      # enough: waiting longer would not make a dropped batch show up.
      def exported_spans
        trace_req = OTLPCollectorServer.listen_to("/v1/traces", :timeout => 2)
        Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest
          .decode(trace_req[:body])
          .resource_spans.flat_map { |rs| rs.scope_spans.flat_map(&:spans) }
      end

      # Asserts the valid transaction made it out next to the invalid one, and
      # returns the invalid transaction's root span.
      def exported_invalid_root_span
        spans = exported_spans
        expect(spans.map(&:name)).to include("MyController#index", invalid_action)
        spans.find { |s| s.name == invalid_action }
      end

      # Asserts the valid transaction made it out next to the invalid one, and
      # returns the single event span under the invalid transaction's root
      # span.
      def exported_invalid_event_span
        spans = exported_spans
        expect(spans.map(&:name)).to include("MyController#index", invalid_action)
        root = spans.find { |s| s.name == invalid_action }
        events = spans.select { |s| s.parent_span_id == root.span_id }
        expect(events.size).to eq(1)
        events.first
      end

      def span_event(span, name)
        event = span.events.find { |e| e.name == name }
        expect(event).not_to be_nil, "expected a #{name.inspect} event on span #{span.name.inspect}"
        event
      end
    end

    def attribute_value(span, key)
      pair = span.attributes.find { |attr| attr.key == key }
      pair&.value&.string_value
    end

    def int_attribute_value(span, key)
      pair = span.attributes.find { |attr| attr.key == key }
      pair&.value&.int_value
    end
  end
end
