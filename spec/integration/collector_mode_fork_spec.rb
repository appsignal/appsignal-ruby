require "opentelemetry/exporter/otlp"
require "opentelemetry/proto/collector/metrics/v1/metrics_service_pb"

describe "Collector mode under fork" do
  before { OTLPCollectorServer.clear }

  it "exports metrics emitted by a forked child without explicit re-init" do
    # The OTel metrics SDK ships fork hooks (ForkHooks in
    # `opentelemetry-metrics-sdk`) that restart the PeriodicMetricReader
    # in the child after a fork. Those hooks are attached when
    # `OpenTelemetry::SDK.configure` runs, which happens in
    # `Appsignal::OpenTelemetry.configure` at boot. This spec locks
    # down that chain: if a future refactor drops the `SDK.configure`
    # call (or otherwise disconnects the fork hooks), the child's
    # metric would queue inside a dead reader and never arrive.
    Runner.new("collector_mode_fork").run

    metric_names = []
    loop do
      req = OTLPCollectorServer.listen_to("/v1/metrics", :timeout => 2)
      msg = Opentelemetry::Proto::Collector::Metrics::V1::ExportMetricsServiceRequest
        .decode(req[:body])
      metric_names.concat(
        msg.resource_metrics.flat_map do |rm|
          rm.scope_metrics.flat_map { |sm| sm.metrics.map(&:name) }
        end
      )
    rescue RuntimeError
      break
    end

    expect(metric_names).to include("forked_child_counter")
  end
end
