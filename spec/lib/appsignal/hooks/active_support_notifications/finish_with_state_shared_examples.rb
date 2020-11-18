shared_examples "activesupport finish_with_state override" do
  let(:instrumenter) { as.instrumenter }

  it "instruments an ActiveSupport::Notifications.start/finish event with payload on finish" do
    listeners_state = instrumenter.start("sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "sql.active_record", :sql => "SQL")

    expect(transaction.to_h["events"]).to match([
      {
        "allocation_count" => kind_of(Integer),
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "child_allocation_count" => kind_of(Integer),
        "child_duration" => kind_of(Float),
        "child_gc_duration" => kind_of(Float),
        "count" => 1,
        "duration" => kind_of(Float),
        "gc_duration" => kind_of(Float),
        "name" => "sql.active_record",
        "start" => kind_of(Float),
        "title" => ""
      }
    ])
  end

  it "does not instrument events whose name starts with a bang" do
    expect(Appsignal::Transaction.current).not_to receive(:start_event)
    expect(Appsignal::Transaction.current).not_to receive(:finish_event)

    listeners_state = instrumenter.start("!sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "!sql.active_record", :sql => "SQL")

    expect(transaction.to_h["events"]).to be_empty
  end
end
