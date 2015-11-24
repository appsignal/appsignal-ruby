require 'spec_helper'

describe "Sequel integration", if: sequel_present? do
  let(:db) { Sequel.sqlite }

  before do
    start_agent
  end

  context "with Sequel" do
    before { Appsignal::Transaction.create('uuid', Appsignal::Transaction::HTTP_REQUEST, 'test') }

    it "should instrument queries" do
      expect( Appsignal::Extension ).to receive(:start_event)
        .at_least(:once)
      expect( Appsignal::Extension ).to receive(:finish_event)
        .at_least(:once)
        .with(kind_of(Integer), "sql.sequel", "", "")

      db['SELECT 1'].all
    end
  end
end
