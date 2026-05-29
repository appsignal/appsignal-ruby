shared_examples "activesupport instrument override in collector mode" do
  it "emits a child span for an event with a registered formatter" do
    return_value = as.instrument("sql.active_record", :sql => "SQL") do
      "value"
    end
    Appsignal::Transaction.complete_current!

    expect(return_value).to eq "value"
    span = event_spans.find { |s| s.name == "sql.active_record" }
    expect(span).not_to be_nil
    expect(span.parent_span_id).to eq(root_span.span_id)
    expect(span.attributes["db.query.text"]).to eq("SQL")
    expect(span.attributes["db.system.name"]).to eq("other_sql")
    expect(span.attributes).not_to have_key("appsignal.title")
    expect(span.attributes).not_to have_key("appsignal.body")
  end

  it "emits a child span with no body attributes for an unregistered formatter" do
    return_value = as.instrument("no-registered.formatter", :key => "something") do
      "value"
    end
    Appsignal::Transaction.complete_current!

    expect(return_value).to eq "value"
    span = event_spans.find { |s| s.name == "no-registered.formatter" }
    expect(span).not_to be_nil
    expect(span.parent_span_id).to eq(root_span.span_id)
    expect(span.attributes).not_to have_key("appsignal.body")
    expect(span.attributes).not_to have_key("appsignal.title")
    expect(span.attributes).not_to have_key("db.query.text")
    expect(span.attributes).not_to have_key("db.system.name")
  end

  it "converts non-string event names to strings" do
    as.instrument(:not_a_string) {} # rubocop:disable Lint/EmptyBlock
    Appsignal::Transaction.complete_current!

    expect(event_spans.map(&:name)).to include("not_a_string")
  end

  it "does not emit a span for events whose name starts with a bang" do
    return_value = as.instrument("!sql.active_record", :sql => "SQL") do
      "value"
    end
    Appsignal::Transaction.complete_current!

    expect(return_value).to eq "value"
    expect(event_spans).to be_empty
  end

  context "when an error is raised in an instrumented block" do
    it "emits the child span and re-raises the error" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")
      Appsignal::Transaction.complete_current!

      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.attributes["db.query.text"]).to eq("SQL")
      expect(span.attributes["db.system.name"]).to eq("other_sql")
    end
  end

  context "when a message is thrown in an instrumented block" do
    it "emits the child span and propagates the throw" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          throw :foo
        end
      end.to throw_symbol(:foo)
      Appsignal::Transaction.complete_current!

      span = event_spans.find { |s| s.name == "sql.active_record" }
      expect(span).not_to be_nil
      expect(span.attributes["db.query.text"]).to eq("SQL")
    end
  end

  context "when a transaction is completed in an instrumented block" do
    it "does not emit a span named after the in-flight event" do
      as.instrument("sql.active_record", :sql => "SQL") do
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to be_completed
      expect(event_spans.map(&:name)).not_to include("sql.active_record")
    end
  end
end
