require "appsignal/integrations/data_mapper"

describe Appsignal::Hooks::DataMapperLogListener do
  module DataMapperLog
    def log(message)
    end
  end

  describe "#log" do
    let(:transaction) { double }
    let(:message) do
      double(
        :query    => "SELECT * from users",
        :duration => 100
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

    before { allow(Appsignal::Transaction).to receive(:current) { transaction } }

    it "should record the log entry in an event" do
      expect(transaction).to receive(:record_event).with(
        "query.data_mapper",
        "DataMapper Query",
        "SELECT * from users",
        100,
        Appsignal::EventFormatter::SQL_BODY_FORMAT
      )
    end

    context "when scheme is not sql-like" do
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

      it "should record the log entry in an event without body" do
        expect(transaction).to receive(:record_event).with(
          "query.data_mapper",
          "DataMapper Query",
          "",
          100,
          Appsignal::EventFormatter::DEFAULT
        )
      end
    end

    after { connection_class.new.log(message) }
  end
end
