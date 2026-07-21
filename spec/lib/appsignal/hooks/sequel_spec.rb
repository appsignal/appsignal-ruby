describe Appsignal::Hooks::SequelHook do
  if DependencyHelper.sequel_present?
    let(:db) do
      if DependencyHelper.running_jruby?
        Sequel.connect("jdbc:sqlite::memory:")
      else
        Sequel.sqlite
      end
    end

    describe "#dependencies_present?" do
      before { start_agent }
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    context "with a transaction" do
      def perform
        db["SELECT 1"].all.to_a
      end

      it "in agent mode", :agent_mode do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        expect(transaction).to include_event(
          "name" => "sql.sequel",
          "title" => "",
          "body" => "SELECT 1",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform
        Appsignal::Transaction.complete_current!

        span = event_spans.find do |s|
          s.name == "sql.sequel" && s.attributes["db.query.text"] == "SELECT 1"
        end
        expect(span).not_to be_nil
        expect(span.kind).to eq(:client)
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes["db.system.name"]).to eq("other_sql")
        expect(span.attributes).not_to have_key("appsignal.body")
        expect(span.attributes["appsignal.category"]).to eq("sql.sequel")
        expect(scope_of(span)).to eq(["appsignal-ruby-sequel", Appsignal::VERSION])
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
