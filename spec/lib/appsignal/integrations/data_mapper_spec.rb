require "appsignal/integrations/data_mapper"

describe Appsignal::Hooks::DataMapperLogListener do
  module DataMapperLog
    def log(message)
    end
  end

  describe "#log" do
    let(:transaction) { http_request_transaction }
    let(:message) do
      double(
        :query    => "SELECT * from users",
        :duration => 100_000_000 # nanoseconds
      )
    end
    let(:connection_class) do
      module DataObjects
        module Sqlite3
          class Connection
            include DataMapperLog
            include Appsignal::Hooks::DataMapperLogListener
          end
        end
      end
    end
    before do
      start_agent
      set_current_transaction(transaction)
    end
    around { |example| keep_transactions { example.run } }

    def log_message
      connection_class.new.log(message)
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

    context "when the scheme is not sql-like" do
      let(:connection_class) do
        module DataObjects
          module MongoDB
            class Connection
              include DataMapperLog
              include Appsignal::Hooks::DataMapperLogListener
            end
          end
        end
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
