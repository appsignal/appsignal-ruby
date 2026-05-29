require_relative "active_support_notifications/instrument_shared_examples"

describe Appsignal::Hooks::ActiveSupportNotificationsHook do
  if active_support_present?
    let(:notifier) { ActiveSupport::Notifications::Fanout.new }
    let(:as) { ActiveSupport::Notifications }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    describe "in agent mode" do
      let(:transaction) { http_request_transaction }
      before do
        start_agent
        set_current_transaction(transaction)
        as.notifier = notifier
      end
      around { |example| keep_transactions { example.run } }

      it_behaves_like "activesupport instrument override"

      if defined?(::ActiveSupport::Notifications::Fanout::Handle)
        require_relative "active_support_notifications/start_finish_shared_examples"

        it_behaves_like "activesupport start finish override"
      end

      if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:start)
        require_relative "active_support_notifications/start_finish_shared_examples"

        it_behaves_like "activesupport start finish override"
      end

      if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:finish_with_state)
        require_relative "active_support_notifications/finish_with_state_shared_examples"

        it_behaves_like "activesupport finish_with_state override"
      end
    end

    describe "in collector mode" do
      require "opentelemetry/sdk"
      require_relative "active_support_notifications/instrument_collector_shared_examples"

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
        # Replace the tracer provider booted by Appsignal::OpenTelemetry.configure
        # with one whose processor pushes into our in-memory exporter, so we
        # can inspect spans inside the test instead of trying to flush them
        # out over OTLP/HTTP. Mirrors transaction_integration_spec.rb.
        ::OpenTelemetry.tracer_provider = tracer_provider
        @transaction = Appsignal::Transaction.create(Appsignal::Transaction::HTTP_REQUEST)
        as.notifier = notifier
      end

      # complete_current! clears both the thread-local and the attached OTel
      # context. spec_helper's clear_current_transaction! only handles the
      # former, so a leaked OTel context would pollute the next test's
      # current_span reading.
      after { Appsignal::Transaction.complete_current! }

      # Bind to the specific Transaction created in `before` (not to
      # Appsignal::Transaction.current, which becomes NilTransaction after
      # `complete_current!` and has no backend).
      let(:transaction) { @transaction }

      def root_span
        span_exporter.finished_spans.find { |s| [:server, :consumer].include?(s.kind) }
      end

      def event_spans
        span_exporter.finished_spans.reject { |s| [:server, :consumer].include?(s.kind) }
      end

      it_behaves_like "activesupport instrument override in collector mode"

      if defined?(::ActiveSupport::Notifications::Fanout::Handle)
        require_relative "active_support_notifications/start_finish_collector_shared_examples"

        it_behaves_like "activesupport start finish override in collector mode"
      end

      if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:start)
        require_relative "active_support_notifications/start_finish_collector_shared_examples"

        it_behaves_like "activesupport start finish override in collector mode"
      end

      if ::ActiveSupport::Notifications::Instrumenter.method_defined?(:finish_with_state)
        require_relative "active_support_notifications/finish_with_state_collector_shared_examples"

        it_behaves_like "activesupport finish_with_state override in collector mode"
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
