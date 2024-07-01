shared_examples "activesupport start finish override" do
  let(:instrumenter) { as.instrumenter }

  it "instruments start/finish events with payload on start ignores payload" do
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

  it "instruments an ActiveSupport::Notifications.start/finish event with payload on finish" do
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

  it "does not instrument events whose name starts with a bang" do
    expect(Appsignal::Transaction.current).not_to receive(:start_event)
    expect(Appsignal::Transaction.current).not_to receive(:finish_event)

    instrumenter.start("!sql.active_record", {})
    instrumenter.finish("!sql.active_record", {})

    expect(transaction).to_not include_events
  end

  context "when a transaction is completed in an instrumented block" do
    it "does not complete the ActiveSupport::Notifications.instrument event" do
      expect(transaction).to receive(:complete)

      instrumenter.start("sql.active_record", {})
      Appsignal::Transaction.complete_current!
      instrumenter.finish("sql.active_record", {})

      expect(transaction).to_not include_events
    end
  end
end
