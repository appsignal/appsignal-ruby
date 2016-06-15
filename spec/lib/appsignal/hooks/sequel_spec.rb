require 'spec_helper'

describe "Sequel integration", if: sequel_present? do
  let(:db) { Sequel.sqlite }

  before do
    start_agent
  end

  context "with Sequel" do
    before { Appsignal::Transaction.create('uuid', Appsignal::Transaction::HTTP_REQUEST, 'test') }

    it "should instrument queries" do
      expect( Appsignal::Transaction.current ).to receive(:start_event)
        .at_least(:once)
      expect( Appsignal::Transaction.current ).to receive(:finish_event)
        .at_least(:once)
        .with("sql.sequel", nil, kind_of(String), 1)

      db['SELECT 1'].all.to_a
    end
  end
end
