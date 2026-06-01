# frozen_string_literal: true

require "opentelemetry/sdk"

RSpec.shared_context "collector mode", :collector_mode do
  let(:span_exporter) { ::OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer_provider) do
    provider = ::OpenTelemetry::SDK::Trace::TracerProvider.new
    provider.add_span_processor(
      ::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(span_exporter)
    )
    provider
  end

  before do
    start_agent(:options => { :collector_endpoint => "http://127.0.0.1:9090" })
    # `Appsignal.start` booted a full SDK tracer provider backed by a
    # BatchSpanProcessor (a background export thread). Shut it down before
    # swapping in the threadless in-memory provider: after the swap it is
    # unreachable and its thread would leak across examples.
    ::OpenTelemetry.tracer_provider.shutdown
    ::OpenTelemetry.tracer_provider = tracer_provider
  end

  after do
    # `clear_current_transaction!` in spec_helper clears the thread-local but
    # not the attached OTel context. `complete_current!` does both.
    Appsignal::Transaction.complete_current!
    # Shut the OTel SDK down so the meter and logger providers' background
    # threads don't accumulate across the suite. The targeted shutdown, not
    # `Appsignal.stop`: stop's `Extension.stop` takes ~2 seconds per call,
    # which across every collector-mode example adds minutes to the suite.
    # Runs before the global `Appsignal::OpenTelemetry.reset!` hook, so the
    # `started?` gate inside the shutdown still passes.
    Appsignal::OpenTelemetry.shutdown
  end

  def root_span
    span_exporter.finished_spans.find { |s| [:server, :consumer].include?(s.kind) }
  end

  def event_spans
    span_exporter.finished_spans.reject { |s| [:server, :consumer].include?(s.kind) }
  end
end

RSpec.configure do |config|
  config.include_context "collector mode", :collector_mode
end
