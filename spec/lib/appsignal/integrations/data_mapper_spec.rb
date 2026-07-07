require "appsignal/integrations/data_mapper"

describe Appsignal::Hooks::DataMapperLogListener do
  describe "#log" do
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

    describe "a SQL-like scheme" do
      let(:connection_class) { DataObjects::Sqlite3::Connection }
      before do
        stub_const("DataObjects::Sqlite3::Connection", Class.new do
          include DataMapperLog
          include Appsignal::Hooks::DataMapperLogListener
        end)
      end

      it "in agent mode", :agent_mode do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        keep_transactions { log_message }

        expect(transaction).to include_event(
          "name" => "query.data_mapper",
          "title" => "DataMapper Query",
          "body" => "SELECT * from users",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
          "duration" => 100.0
        )
      end

      it "in collector mode", :collector_mode do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        log_message
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("DataMapper Query")
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)
        attrs = span.attributes
        expect(attrs["db.query.text"]).to eq("SELECT * from users")
        expect(attrs["db.system.name"]).to eq("other_sql")
        expect(attrs["appsignal.category"]).to eq("query.data_mapper")
        expect(attrs).not_to have_key("appsignal.body")
        observed = span.end_timestamp - span.start_timestamp
        expect(observed).to be_within(50_000_000).of(100_000_000)
      end
    end

    describe "a non-SQL scheme" do
      let(:connection_class) { DataObjects::MongoDB::Connection }
      before do
        stub_const("DataObjects::MongoDB::Connection", Class.new do
          include DataMapperLog
          include Appsignal::Hooks::DataMapperLogListener
        end)
      end

      it "in agent mode", :agent_mode do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        keep_transactions { log_message }

        expect(transaction).to include_event(
          "name" => "query.data_mapper",
          "title" => "DataMapper Query",
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "duration" => 100.0
        )
      end

      it "in collector mode", :collector_mode do
        transaction = http_request_transaction
        set_current_transaction(transaction)

        log_message
        Appsignal::Transaction.complete_current!

        expect(event_spans.size).to eq(1)
        span = event_spans.first
        expect(span.name).to eq("DataMapper Query")
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)
        attrs = span.attributes
        expect(attrs["appsignal.category"]).to eq("query.data_mapper")
        expect(attrs).not_to have_key("appsignal.body")
        expect(attrs).not_to have_key("db.query.text")
        expect(attrs).not_to have_key("db.system.name")
        observed = span.end_timestamp - span.start_timestamp
        expect(observed).to be_within(50_000_000).of(100_000_000)
      end
    end
  end
end
