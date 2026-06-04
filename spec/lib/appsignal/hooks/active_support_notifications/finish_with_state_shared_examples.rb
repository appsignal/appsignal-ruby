shared_examples "activesupport finish_with_state override" do
  let(:instrumenter) { as.instrumenter }

  describe "a finish_with_state event" do
    def perform
      listeners_state = instrumenter.start("sql.active_record", {})
      instrumenter.finish_with_state(listeners_state, "sql.active_record", :sql => "SQL")
    end

    it "in agent mode", :agent_mode do
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
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans.size).to eq(1)
      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
    end
  end

  describe "an event whose name starts with a bang" do
    def perform
      listeners_state = instrumenter.start("!sql.active_record", {})
      instrumenter.finish_with_state(listeners_state, "!sql.active_record", :sql => "SQL")
    end

    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform

      expect(transaction).to_not include_events
    end

    it "in collector mode", :collector_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      perform
      Appsignal::Transaction.complete_current!

      expect(event_spans).to be_empty
    end
  end
end
