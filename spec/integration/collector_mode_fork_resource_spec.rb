# Skipped on JRuby because `Process.fork` raises NotImplementedError there.
if DependencyHelper.opentelemetry_present? && !DependencyHelper.running_jruby?
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/proto/collector/trace/v1/trace_service_pb"
  require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"
  require "opentelemetry/proto/collector/logs/v1/logs_service_pb"

  describe "Collector mode resource under fork" do
    before { OTLPCollectorServer.clear }

    it "exports the child's data with the child's process ID and service instance ID" do
      runner = Runner.new(
        "collector_mode_fork_resource",
        :env => OTLPCollectorServer.env.merge("APPSIGNAL_LOG" => "stdout")
      )
      runner.run

      parent_pid = runner.output[/PARENT_PID=(\d+)/, 1].to_i
      child_pid = runner.output[/CHILD_PID=(\d+)/, 1].to_i

      resources = {
        "span" => span_resources,
        "metric" => metric_resources,
        "log" => log_resources
      }

      resources.each do |signal, by_process|
        parent = by_process.fetch("parent") { raise "No parent #{signal} exported" }
        child = by_process.fetch("child") { raise "No child #{signal} exported" }

        expect(parent["process.pid"]).to eq(parent_pid)
        expect(child["process.pid"]).to eq(child_pid)
        expect(parent["service.instance.id"]).to match(/\A\h{8}-\h{4}-4\h{3}-\h{4}-\h{12}\z/)
        expect(child["service.instance.id"]).to match(/\A\h{8}-\h{4}-4\h{3}-\h{4}-\h{12}\z/)
        expect(child["service.instance.id"]).not_to eq(parent["service.instance.id"])
      end
      child_instance_ids = resources.values.map { |by_process| by_process["child"] }
        .map { |attributes| attributes["service.instance.id"] }
      expect(child_instance_ids.uniq.size).to eq(1)

      expect(runner.output).not_to include(Appsignal::OpenTelemetry::ProcessResource::REFRESH_FAILED)
    end

    def drain(path, message_class)
      queue = OTLPCollectorServer.received[path]
      Array.new(queue.size) { message_class.decode(queue.pop[:body]) }
    end

    def resource_attributes(resource)
      resource.attributes.to_h do |kv|
        value = kv.value
        [kv.key, value.value == :int_value ? value.int_value : value.string_value]
      end
    end

    def span_resources
      drain("/v1/traces", Opentelemetry::Proto::Collector::Trace::V1::ExportTraceServiceRequest)
        .flat_map(&:resource_spans).each_with_object({}) do |rs, by_process|
          rs.scope_spans.flat_map(&:spans).each do |span|
            process = span.name[/\A(parent|child)#run\z/, 1]
            by_process[process] = resource_attributes(rs.resource) if process
          end
        end
    end

    def metric_resources
      drain("/v1/metrics", Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest)
        .flat_map(&:resource_metrics).each_with_object({}) do |rm, by_process|
          rm.scope_metrics.flat_map(&:metrics).each do |metric|
            next unless metric.name == "fork_resource_counter"

            metric.sum.data_points.each do |dp|
              process = dp.attributes.find { |kv| kv.key == "process" }&.value&.string_value
              by_process[process] = resource_attributes(rm.resource) if process
            end
          end
        end
    end

    def log_resources
      drain("/v1/logs", Opentelemetry::Proto::Collector::Logs::V1::ExportLogsServiceRequest)
        .flat_map(&:resource_logs).each_with_object({}) do |rl, by_process|
          rl.scope_logs.flat_map(&:log_records).each do |record|
            process = record.body.string_value[/\A(parent|child) log\z/, 1]
            by_process[process] = resource_attributes(rl.resource) if process
          end
        end
    end
  end
end
