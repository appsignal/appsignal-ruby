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
      start_agent
      set_current_transaction(transaction)
    end
    around { |example| keep_transactions { example.run } }

    def log_message
      connection_class.new.log(message)
    end

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
end
