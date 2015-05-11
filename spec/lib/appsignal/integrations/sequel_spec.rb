require 'spec_helper'

describe "Sequel integration", if: sequel_present? do
  let(:file) { File.expand_path('lib/appsignal/integrations/sequel.rb') }
  let(:db)   { Sequel.sqlite }

  before do
    load file
    start_agent
  end

  context "with Sequel" do
    before { Appsignal::Transaction.create('uuid', 'test') }

    it "should instrument queries" do
      expect( Appsignal::Extension ).to receive(:start_event)
        .at_least(:once)
        .with('uuid')
      expect( Appsignal::Extension ).to receive(:finish_event)
        .at_least(:once)
        .with('uuid', "sql.sequel", "", "")

      db['SELECT 1'].all
    end
  end
end
