describe Appsignal::Hooks::SequelHook do
  if DependencyHelper.sequel_present?
    let(:db) { Sequel.sqlite }

    before :all do
      start_agent
    end

    its(:dependencies_present?) { should be_true }

    context "with a transaction" do
      let(:transaction) { Appsignal::Transaction.current }
      before do
        Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
        db.logger = Logger.new($stdout) # To test #log_duration call
      end

      it "should instrument queries" do
        expect(transaction).to receive(:start_event).at_least(:once)
        expect(transaction).to receive(:finish_event)
          .at_least(:once)
          .with("sql.sequel", nil, kind_of(String), 1)

        expect(db).to receive(:log_duration).at_least(:once)

        db["SELECT 1"].all.to_a
      end
    end
  else
    its(:dependencies_present?) { should be_false }
  end
end
