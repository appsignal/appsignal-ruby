shared_examples "activesupport start finish override in collector mode" do
  let(:instrumenter) { as.instrumenter }

  it "ignores the payload from the start call and uses the finish payload" do
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

  it "uses the payload provided at finish" do
    instrumenter.start("sql.active_record", {})
    instrumenter.finish("sql.active_record", :sql => "SQL")
    Appsignal::Transaction.complete_current!

    span = event_spans.find { |s| s.name == "sql.active_record" }
    expect(span).not_to be_nil
    expect(span.parent_span_id).to eq(root_span.span_id)
    expect(span.attributes["db.query.text"]).to eq("SQL")
    expect(span.attributes["db.system.name"]).to eq("other_sql")
  end

  it "does not emit a span for events whose name starts with a bang" do
    instrumenter.start("!sql.active_record", {})
    instrumenter.finish("!sql.active_record", {})
    Appsignal::Transaction.complete_current!

    expect(event_spans).to be_empty
  end

  context "when the transaction is completed between start and finish" do
    it "does not emit a span named after the in-flight event" do
      instrumenter.start("sql.active_record", {})
      Appsignal::Transaction.complete_current!
      instrumenter.finish("sql.active_record", {})

      expect(transaction).to be_completed
      expect(event_spans.map(&:name)).not_to include("sql.active_record")
    end
  end
end
