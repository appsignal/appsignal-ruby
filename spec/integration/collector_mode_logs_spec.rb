if DependencyHelper.opentelemetry_present?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

  describe "AppSignal collector mode log helpers" do
    before { OTLPCollectorServer.clear }

    it "emits OTLP log records through Appsignal::Logger" do
      runner = Runner.new("collector_mode_logs", :env => OTLPCollectorServer.env)
      runner.run

      log_req = OTLPCollectorServer.listen_to("/v1/logs")
      log_msg = Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
        .decode(log_req[:body])

      scope_logs = log_msg.resource_logs.flat_map(&:scope_logs)
      expect(scope_logs.map { |sl| sl.scope.name }).to include("appsignal-logger")

      records = scope_logs.flat_map(&:log_records)
      by_body = records.to_h { |record| [record.body.string_value, record] }

      expect(by_body.keys).to include("info line", "warn line", "error line")

      info_record = by_body.fetch("info line")
      expect(info_record.severity_number).to eq(:SEVERITY_NUMBER_INFO)
      expect(info_record.severity_text).to eq("INFO")
      expect(attribute_value(info_record, "appsignal.group").string_value).to eq("my-group")
      expect(attribute_value(info_record, "appsignal.format").string_value).to eq("json")
      expect(attribute_value(info_record, "service").string_value).to eq("runner")
      expect(attribute_value(info_record, "tag").string_value).to eq("value")

      warn_record = by_body.fetch("warn line")
      expect(warn_record.severity_number).to eq(:SEVERITY_NUMBER_WARN)
      expect(warn_record.severity_text).to eq("WARN")

      error_record = by_body.fetch("error line")
      expect(error_record.severity_number).to eq(:SEVERITY_NUMBER_ERROR)
      expect(error_record.severity_text).to eq("ERROR")
    end

    context "with invalid UTF-8" do
      # The OTLP exporter encodes each batch to protobuf in one go, and
      # protobuf refuses strings that are not valid UTF-8. One invalid string
      # then costs the whole batch, valid data included. Each example puts
      # invalid UTF-8 in one place a log line accepts input, and asserts that
      # the valid log line emitted alongside it, and the log line carrying the
      # invalid string, are both exported. The invalid bytes are expected to
      # arrive replaced with U+FFFD.
      let(:replaced) { "caf\u{FFFD}" }

      {
        "a UTF-8 string with invalid bytes" => "utf8",
        "a binary string with non-ASCII bytes" => "binary"
      }.each do |description, encoding|
        context "as #{description}" do
          let(:encoding) { encoding }

          it "exports logs with an invalid message" do
            run_invalid_utf8_scenario("log_message")

            bodies = exported_log_records.map { |record| record.body.string_value }
            expect(bodies).to include("info line", replaced)
          end

          it "exports logs with an invalid attribute value" do
            run_invalid_utf8_scenario("log_attribute_value")

            record = exported_invalid_log_record
            expect(attribute_value(record, "invalid_attribute").string_value).to eq(replaced)
          end

          it "exports logs with an invalid attribute key" do
            run_invalid_utf8_scenario("log_attribute_key")

            record = exported_invalid_log_record
            expect(attribute_value(record, replaced).string_value).to eq("value")
          end

          it "exports logs with an invalid group" do
            run_invalid_utf8_scenario("log_group")

            record = exported_invalid_log_record
            expect(attribute_value(record, "appsignal.group").string_value).to eq(replaced)
          end
        end
      end

      def run_invalid_utf8_scenario(scenario)
        runner = Runner.new(
          "collector_mode_logs",
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
      def exported_log_records
        log_req = OTLPCollectorServer.listen_to("/v1/logs", :timeout => 2)
        Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest
          .decode(log_req[:body])
          .resource_logs.flat_map(&:scope_logs)
          .flat_map(&:log_records)
      end

      # Asserts the valid log line made it out next to the invalid one, and
      # returns the invalid log record.
      def exported_invalid_log_record
        records = exported_log_records
        bodies = records.map { |record| record.body.string_value }
        expect(bodies).to include("info line", "invalid line")
        records.find { |record| record.body.string_value == "invalid line" }
      end
    end

    def attribute_value(record, key)
      record.attributes.find { |kv| kv.key == key }&.value
    end
  end
end
