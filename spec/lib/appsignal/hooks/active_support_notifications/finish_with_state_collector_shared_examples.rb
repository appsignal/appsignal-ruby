shared_examples "activesupport finish_with_state override in collector mode" do
  let(:instrumenter) { as.instrumenter }

  it "uses the payload provided at finish_with_state" do
    listeners_state = instrumenter.start("sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "sql.active_record", :sql => "SQL")
    Appsignal::Transaction.complete_current!

    span = event_spans.find { |s| s.name == "sql.active_record" }
    expect(span).not_to be_nil
    expect(span.parent_span_id).to eq(root_span.span_id)
    expect(span.attributes["db.query.text"]).to eq("SQL")
    expect(span.attributes["db.system.name"]).to eq("other_sql")
  end

  it "does not emit a span for events whose name starts with a bang" do
    listeners_state = instrumenter.start("!sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "!sql.active_record", :sql => "SQL")
    Appsignal::Transaction.complete_current!

    expect(event_spans).to be_empty
  end
end
