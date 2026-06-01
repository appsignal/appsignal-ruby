shared_examples "activesupport start finish override" do
  let(:instrumenter) { as.instrumenter }

  describe "a start/finish event whose payload is provided at start" do
    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("sql.active_record", :sql => "SQL")
      instrumenter.finish("sql.active_record", {})

      expect(transaction).to include_event(
        "body" => "",
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

      instrumenter.start("sql.active_record", :sql => "SQL")
      instrumenter.finish("sql.active_record", {})
      Appsignal::Transaction.complete_current!

      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      # The formatter received an empty finish payload, so body is empty —
      # the OTel backend skips writing db.query.text / db.system.name.
      expect(span.attributes).not_to have_key("db.query.text")
      expect(span.attributes).not_to have_key("db.system.name")
    end
  end

  describe "a start/finish event whose payload is provided at finish" do
    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("sql.active_record", {})
      instrumenter.finish("sql.active_record", :sql => "SQL")

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

      instrumenter.start("sql.active_record", {})
      instrumenter.finish("sql.active_record", :sql => "SQL")
      Appsignal::Transaction.complete_current!

      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.parent_span_id).to eq(root_span.span_id)
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
    end
  end

  describe "an event whose name starts with a bang" do
    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("!sql.active_record", {})
      instrumenter.finish("!sql.active_record", {})

      expect(transaction).to_not include_events
    end

    it "in collector mode", :collector_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("!sql.active_record", {})
      instrumenter.finish("!sql.active_record", {})
      Appsignal::Transaction.complete_current!

      expect(event_spans).to be_empty
    end
  end

  describe "when the transaction is completed between start and finish" do
    it "in agent mode", :agent_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("sql.active_record", {})
      Appsignal::Transaction.complete_current!
      instrumenter.finish("sql.active_record", {})

      expect(transaction).to_not include_events
      expect(transaction).to be_completed
    end

    it "in collector mode", :collector_mode do
      transaction = http_request_transaction
      set_current_transaction(transaction)
      as.notifier = notifier

      instrumenter.start("sql.active_record", {})
      Appsignal::Transaction.complete_current!
      instrumenter.finish("sql.active_record", {})

      expect(transaction).to be_completed
      expect(event_spans.map(&:name)).not_to include("sql.active_record")
    end
  end
end
