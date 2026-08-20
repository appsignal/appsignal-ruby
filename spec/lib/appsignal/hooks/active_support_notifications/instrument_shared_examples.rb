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
      # The scope is derived from the event group (the part after the last dot).
      expect(scope_of(span)).to eq(["appsignal-ruby/active_record", Appsignal::VERSION])
      expect(span.attributes).not_to have_key("appsignal.body")
      expect(span.attributes).not_to have_key("error.type")
    end
  end

  describe "an ActiveRecord SQL query event with a connection" do
    let(:connection) { double(:adapter_name => "PostgreSQL") }

    def perform
      as.instrument("sql.active_record", :sql => "SQL", :connection => connection) { "value" }
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
      # The connection's own adapter name names the engine, rather than the
      # SQL sentinel every other unrecognized adapter falls back to.
      expect(span.attributes["db.system.name"]).to eq("postgresql")
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
      expect(scope_of(span)).to eq(["appsignal-ruby/sequel", Appsignal::VERSION])
      expect(span.attributes).not_to have_key("appsignal.body")
    end
  end

  describe "an Elasticsearch search event" do
    def perform
      as.instrument(
        "search.elasticsearch",
        :name => "Search",
        :klass => "User",
        :search => { :index => "users" }
      ) { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to include_event(
        "name" => "search.elasticsearch",
        "title" => "Search: User",
        # The formatter inspects the sanitized search, and Hash#inspect changed
        # format in Ruby 3.4, so match on the content rather than the layout.
        "body" => a_string_including("users")
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      span = event_span_for("search.elasticsearch")
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # A search is an outgoing call to the cluster, so it carries CLIENT kind.
      expect(span.kind).to eq(:client)
      # There is no SQL body to infer the datastore from, so it is named
      # explicitly. Without it the trace timeline cannot tell this span apart
      # from any other kind of work.
      expect(span.attributes["db.system.name"]).to eq("elasticsearch")
      # This notification is only emitted for a search, so that is the
      # operation. The index comes off the search itself.
      expect(span.attributes["db.operation.name"]).to eq("search")
      expect(span.attributes["db.collection.name"]).to eq("users")
      expect(event_category(span)).to eq("search.elasticsearch")
      expect(scope_of(span)).to eq(["appsignal-ruby/elasticsearch", Appsignal::VERSION])
    end
  end

  describe "an Elasticsearch search event across more than one index" do
    def perform
      as.instrument(
        "search.elasticsearch",
        :name => "Search",
        :klass => "User",
        :search => { :index => ["users", "admins"] }
      ) { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      expect(transaction).to include_event(
        "name" => "search.elasticsearch",
        "title" => "Search: User",
        "body" => a_string_including("users")
      )
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      span = event_span_for("search.elasticsearch")
      expect(span).not_to be_nil
      expect(span.attributes["db.operation.name"]).to eq("search")
      # The attribute names one index, so a search across several is left
      # without it rather than described with a value that is not an index name.
      expect(span.attributes).to_not have_key("db.collection.name")
    end
  end

  describe "a template render event" do
    def perform
      as.instrument("render_template.action_view", :identifier => "/app/views/a.erb") { "value" }
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      # The title comes from the Action View formatter, which only registers
      # when Rails is loaded. These shared examples also run under gemfiles
      # that have ActiveSupport without Rails, where the event has no title,
      # so match any String rather than one particular value.
      expect(transaction).to include_event(
        "name" => "render_template.action_view",
        "title" => kind_of(String)
      )
      # The render group only means something to the trace timeline, so
      # nothing is recorded for it here.
      expect(transaction).to_not include_tags("appsignal.group" => "render")
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      expect(perform).to eq "value"
      Appsignal::Transaction.complete_current!

      span = event_span_for("render_template.action_view")
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # There is no OpenTelemetry convention for template rendering, so the
      # span says which group it belongs to directly.
      expect(span.attributes["appsignal.group"]).to eq("render")
      expect(scope_of(span)).to eq(["appsignal-ruby/action_view", Appsignal::VERSION])
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
      expect(scope_of(span)).to eq(["appsignal-ruby/formatter", Appsignal::VERSION])
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
      # No group (no dot) in the name, so it falls back to the default scope.
      expect(scope_of(span)).to eq(["appsignal-ruby", Appsignal::VERSION])
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

  describe "an event claimed by a dedicated integration" do
    # An integration claims its event as it installs, so which events are
    # claimed depends on which integrations are running. Claim one here, so
    # that this covers the generic path leaving a claimed event alone whichever
    # integrations this gemfile happens to have.
    before do
      Appsignal::EventFormatter.register(
        "claimed.example",
        Appsignal::EventFormatter::RecordedElsewhere
      )
    end

    after do
      Appsignal::EventFormatter.unregister(
        "claimed.example",
        Appsignal::EventFormatter::RecordedElsewhere
      )
    end

    def perform
      as.instrument("claimed.example", :method => :get) { "value" }
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
      # The block raised, so the operation the span describes failed.
      expect(span.attributes["error.type"]).to eq("ExampleException")
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
