describe Appsignal::Hooks::SequelHook do
  describe ".sequel_db_attributes" do
    subject { described_class.sequel_db_attributes(database) }

    context "with a recognised engine and a named database" do
      let(:database) do
        double(:database_type => :postgres, :opts => { :database => "app_production" })
      end

      it "names both the engine and the database" do
        expect(subject).to eq(
          "db.system.name" => "postgresql",
          "db.namespace" => "app_production"
        )
      end
    end

    context "with an in-memory database, which Sequel names with no :database option" do
      let(:database) { double(:database_type => :sqlite, :opts => {}) }

      it "names the engine without a namespace" do
        expect(subject).to eq("db.system.name" => "sqlite")
      end
    end

    context "with an engine the mapping does not recognise" do
      let(:database) { double(:database_type => :db2, :opts => {}) }

      it "names neither, leaving the SQL sentinel to apply" do
        expect(subject).to eq({})
      end
    end

    context "with an engine that only the older semantic conventions map" do
      let(:database) { double(:database_type => :oracle, :opts => {}) }

      it "names the engine with the older semantic conventions value" do
        expect(subject).to eq("db.system.name" => "oracle")
      end
    end
  end

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
        # The Sequel::Database's own database_type names the engine, rather
        # than the SQL sentinel every unrecognized engine falls back to.
        expect(span.attributes["db.system.name"]).to eq("sqlite")
        # This in-memory database has no :database connection option, so
        # there is no name to put in db.namespace.
        expect(span.attributes).not_to have_key("db.namespace")
        expect(span.attributes).not_to have_key("appsignal.body")
        expect(event_category(span)).to eq("sql.sequel")
        expect(scope_of(span)).to eq(["appsignal-ruby/sequel", Appsignal::VERSION])
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
