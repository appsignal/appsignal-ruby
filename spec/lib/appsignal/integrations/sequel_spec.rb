require 'spec_helper'

if sequel_present?
  require 'sequel'

  describe "Sequel integration" do
    let(:file) { File.expand_path('lib/appsignal/integrations/sequel.rb') }
    let(:db)   { Sequel.sqlite }

    before do
      load file
      db.extension :appsignal_instrumentation
      start_agent
    end

    context "with Sequel" do
      before { Appsignal::Transaction.create('uuid', 'test') }

      it "should instrument queries" do
        expect { db['SELECT 1'].all }
          .to change {Appsignal::Transaction.current.events.empty? }
          .from(true).to(false)
      end
    end
  end
end
