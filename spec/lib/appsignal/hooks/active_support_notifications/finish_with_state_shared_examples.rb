shared_examples "activesupport finish_with_state override" do
  let(:instrumenter) { as.instrumenter }

  it "instruments an ActiveSupport::Notifications.start/finish event with payload on finish" do
    listeners_state = instrumenter.start("sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "sql.active_record", :sql => "SQL")

    expect(transaction).to include_event(
      "body" => "SQL",
      "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
      "count" => 1,
      "name" => "sql.active_record",
      "title" => ""
    )
  end

  it "does not instrument events whose name starts with a bang" do
    listeners_state = instrumenter.start("!sql.active_record", {})
    instrumenter.finish_with_state(listeners_state, "!sql.active_record", :sql => "SQL")

    expect(transaction).to_not include_events
  end
end
