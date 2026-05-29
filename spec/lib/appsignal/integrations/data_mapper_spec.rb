require "appsignal/integrations/data_mapper"

describe Appsignal::Hooks::DataMapperLogListener do
  describe "#log" do
    let(:transaction) { http_request_transaction }
    let(:message) do
      double(
        :query    => "SELECT * from users",
        :duration => 100_000_000 # nanoseconds
      )
    end
    before do
      stub_const("DataMapperLog", Module.new do
        def log(message)
        end
      end)
      stub_const("DataObjects", Module.new)
    end

    def log_message
      connection_class.new.log(message)
    end

    context "in agent mode" do
      before do
        start_agent
        set_current_transaction(transaction)
      end
      around { |example| keep_transactions { example.run } }

      context "when the scheme is SQL-like" do
        let(:connection_class) { DataObjects::Sqlite3::Connection }
        before do
          stub_const("DataObjects::Sqlite3::Connection", Class.new do
            include DataMapperLog
            include Appsignal::Hooks::DataMapperLogListener
          end)
        end

        it "records the log entry in an event" do
          log_message

          expect(transaction).to include_event(
            "name" => "query.data_mapper",
            "title" => "DataMapper Query",
            "body" => "SELECT * from users",
            "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
            "duration" => 100.0
          )
        end
      end

      context "when the scheme is not SQL-like" do
        let(:connection_class) { DataObjects::MongoDB::Connection }
        before do
          stub_const("DataObjects::MongoDB::Connection", Class.new do
            include DataMapperLog
            include Appsignal::Hooks::DataMapperLogListener
          end)
        end

        it "records the log entry in an event without body" do
          log_message

          expect(transaction).to include_event(
            "name" => "query.data_mapper",
            "title" => "DataMapper Query",
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "duration" => 100.0
          )
        end
      end
    end

    context "in collector mode" do
      require "opentelemetry/sdk"

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
        # with one whose processor pushes into our in-memory exporter, so we can
        # inspect spans inside the test instead of trying to flush them out over
        # OTLP/HTTP.
        ::OpenTelemetry.tracer_provider = tracer_provider
        set_current_transaction(transaction)
      end
      after { Appsignal::Transaction.complete_current! }

      def root_span
        span_exporter.finished_spans.find { |s| [:server, :consumer].include?(s.kind) }
      end

      def event_spans
        span_exporter.finished_spans.reject { |s| [:server, :consumer].include?(s.kind) }
      end

      context "when the scheme is SQL-like" do
        let(:connection_class) { DataObjects::Sqlite3::Connection }
        before do
          stub_const("DataObjects::Sqlite3::Connection", Class.new do
            include DataMapperLog
            include Appsignal::Hooks::DataMapperLogListener
          end)
        end

        it "emits a child span with SQL semantic attributes and the recorded duration" do
          log_message
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("query.data_mapper")
          expect(span.parent_span_id).to eq(root_span.span_id)
          attrs = span.attributes
          expect(attrs["db.query.text"]).to eq("SELECT * from users")
          expect(attrs["db.system.name"]).to eq("other_sql")
          expect(attrs["appsignal.title"]).to eq("DataMapper Query")
          expect(attrs).not_to have_key("appsignal.body")
          observed = span.end_timestamp - span.start_timestamp
          expect(observed).to be_within(50_000_000).of(100_000_000)
        end
      end

      context "when the scheme is not SQL-like" do
        let(:connection_class) { DataObjects::MongoDB::Connection }
        before do
          stub_const("DataObjects::MongoDB::Connection", Class.new do
            include DataMapperLog
            include Appsignal::Hooks::DataMapperLogListener
          end)
        end

        it "emits a child span with no body and the recorded duration" do
          log_message
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("query.data_mapper")
          expect(span.parent_span_id).to eq(root_span.span_id)
          attrs = span.attributes
          expect(attrs["appsignal.title"]).to eq("DataMapper Query")
          expect(attrs).not_to have_key("appsignal.body")
          expect(attrs).not_to have_key("db.query.text")
          expect(attrs).not_to have_key("db.system.name")
          observed = span.end_timestamp - span.start_timestamp
          expect(observed).to be_within(50_000_000).of(100_000_000)
        end
      end
    end
  end
end
