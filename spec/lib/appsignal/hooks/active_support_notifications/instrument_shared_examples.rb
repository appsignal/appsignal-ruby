shared_examples "activesupport instrument override" do
  describe "an event with a registered formatter" do
    def perform
      as.instrument("sql.active_record", :sql => "SQL") { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.active_record",
        "title" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A database query is an outgoing call, so it carries CLIENT kind.
      expect(span.kind).to eq(:client)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
      expect(event_category(span)).to eq("sql.active_record")
      expect(span.attributes).not_to have_key("appsignal.body")
    end
  end

  describe "a Sequel query event (emitted by sequel-rails)" do
    def perform
      as.instrument(
        "sql.sequel",
        :name => "Sequel::Postgres::Database",
        :sql => "SQL"
      ) { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.sequel",
        "title" => "Sequel::Postgres::Database"
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_span_for("sql.sequel")
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A database query is an outgoing call, so it carries CLIENT kind.
      expect(span.kind).to eq(:client)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
      expect(event_category(span)).to eq("sql.sequel")
      expect(span.attributes).not_to have_key("appsignal.body")
    end
  end

  describe "an event with no registered formatter" do
    def perform
      as.instrument("no-registered.formatter", :key => "something") { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to include_event(
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "count" => 1,
        "name" => "no-registered.formatter",
        "title" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.find { |s| s.name == "no-registered.formatter" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A plain event is not an outgoing call, so it keeps the default kind.
      expect(span.kind).to eq(:internal)
      expect(span.attributes).not_to have_key("appsignal.body")
      expect(event_category(span)).to eq("no-registered.formatter")
      expect(span.attributes).not_to have_key("db.query.text")
      expect(span.attributes).not_to have_key("db.system.name")
    end
  end

  describe "an event with a non-string name" do
    def perform
      as.instrument(:not_a_string) {} # rubocop:disable Lint/EmptyBlock
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to include_event(
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "count" => 1,
        "name" => "not_a_string",
        "title" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      expect(event_spans.map(&:name)).to include("not_a_string")
      span = event_spans.find { |s| s.name == "not_a_string" }
      expect(event_category(span)).to eq("not_a_string")
    end
  end

  describe "an event whose name starts with a bang" do
    def perform
      as.instrument("!sql.active_record", :sql => "SQL") { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to_not include_events
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      expect(event_spans).to be_empty
    end
  end

  describe "a suppressed event, recorded by a dedicated integration" do
    def perform
      as.instrument("request.faraday", :method => :get) { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to_not include_events
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      expect(event_spans).to be_empty
    end
  end

  describe "when an error is raised in an instrumented block" do
    def perform
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.active_record",
        "title" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A database query is an outgoing call, so it carries CLIENT kind.
      expect(span.kind).to eq(:client)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
    end
  end

  describe "when a message is thrown in an instrumented block" do
    def perform
      expect do
        as.instrument("sql.active_record", :sql => "SQL") { throw :foo }
      end.to throw_symbol(:foo)
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.active_record",
        "title" => ""
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A database query is an outgoing call, so it carries CLIENT kind.
      expect(span.kind).to eq(:client)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
    end
  end

  describe "when the transaction is completed inside an instrumented block" do
    def perform
      as.instrument("sql.active_record", :sql => "SQL") do
        Appsignal::Transaction.complete_current!
      end
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to_not include_events
      expect(transaction).to be_completed
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to be_completed
      expect(event_spans.map(&:name)).not_to include("sql.active_record")
    end
  end
end
