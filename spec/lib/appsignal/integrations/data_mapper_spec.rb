require 'spec_helper'
require 'appsignal/integrations/data_mapper'

describe Appsignal::Hooks::DataMapperLogListener do

  module DataMapperLog
    def log(message)
    end
  end

  class DataMapperTestClass
    include DataMapperLog
    include Appsignal::Hooks::DataMapperLogListener

    def initialize(uri)
      @uri = uri
    end
  end

  describe "#log" do
    let!(:data_mapper_class) { DataMapperTestClass.new(uri) }
    let(:uri)                { double(:scheme => 'mysql') }
    let(:transaction)        { double }
    let(:message) do
      double(
        :query    => "SELECT * from users",
        :duration => 100
      )
    end

    before do
      Appsignal::Transaction.stub(:current) { transaction }
    end

    it "should record the log entry in an event" do
      expect( transaction ).to receive(:record_event).with(
        'query.data_mapper',
        'DataMapper Query',
        "SELECT * from users",
        100,
        Appsignal::EventFormatter::SQL_BODY_FORMAT
      )
    end

    context "when scheme is not sql-like" do
      let(:uri) { double(:scheme => 'mongodb') }

      it "should record the log entry in an event without body" do
        expect( transaction ).to receive(:record_event).with(
          'query.data_mapper',
          'DataMapper Query',
          "",
          100,
          Appsignal::EventFormatter::DEFAULT
        )
      end
    end

    after { data_mapper_class.log(message) }
  end
end
