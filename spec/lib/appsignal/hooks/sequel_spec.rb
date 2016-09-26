describe Appsignal::Hooks::SequelHook do
  if DependencyHelper.sequel_present?
    let(:db) { Sequel.sqlite }

    before :all do
      start_agent
    end

    its(:dependencies_present?) { should be_true }

    context "with a transaction" do
      it "should instrument queries" do
        Appsignal::Transaction.create('uuid', Appsignal::Transaction::HTTP_REQUEST, 'test')
        expect( Appsignal::Transaction.current ).to receive(:start_event)
          .at_least(:once)
        expect( Appsignal::Transaction.current ).to receive(:finish_event)
          .at_least(:once)
          .with("sql.sequel", nil, kind_of(String), 1)

        db['SELECT 1'].all.to_a
      end
    end
  else
    its(:dependencies_present?) { should be_false }
  end
end
