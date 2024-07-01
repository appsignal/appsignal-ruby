shared_examples "activesupport instrument override" do
  it "instruments an ActiveSupport::Notifications.instrument event" do
    return_value = as.instrument("sql.active_record", :sql => "SQL") do
      "value"
    end

    expect(return_value).to eq "value"
    expect(transaction).to include_event(
      "body" => "SQL",
      "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
      "count" => 1,
      "name" => "sql.active_record",
      "title" => ""
    )
  end

  it "instruments an ActiveSupport::Notifications.instrument event with no registered formatter" do
    return_value = as.instrument("no-registered.formatter", :key => "something") do
      "value"
    end

    expect(return_value).to eq "value"
    expect(transaction).to include_event(
      "body" => "",
      "body_format" => Appsignal::EventFormatter::DEFAULT,
      "count" => 1,
      "name" => "no-registered.formatter",
      "title" => ""
    )
  end

  it "converts non-string names to strings" do
    as.instrument(:not_a_string) {} # rubocop:disable Lint/EmptyBlock
    expect(transaction).to include_event(
      "body" => "",
      "body_format" => Appsignal::EventFormatter::DEFAULT,
      "count" => 1,
      "name" => "not_a_string",
      "title" => ""
    )
  end

  it "does not instrument events whose name starts with a bang" do
    return_value = as.instrument("!sql.active_record", :sql => "SQL") do
      "value"
    end

    expect(return_value).to eq "value"

    expect(transaction).to_not include_events
  end

  context "when an error is raised in an instrumented block" do
    it "instruments an ActiveSupport::Notifications.instrument event" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")

      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.active_record",
        "title" => ""
      )
    end
  end

  context "when a message is thrown in an instrumented block" do
    it "instruments an ActiveSupport::Notifications.instrument event" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          throw :foo
        end
      end.to throw_symbol(:foo)

      expect(transaction).to include_event(
        "body" => "SQL",
        "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT,
        "count" => 1,
        "name" => "sql.active_record",
        "title" => ""
      )
    end
  end

  context "when a transaction is completed in an instrumented block" do
    it "does not complete the ActiveSupport::Notifications.instrument event" do
      expect(transaction).to receive(:complete)
      as.instrument("sql.active_record", :sql => "SQL") do
        Appsignal::Transaction.complete_current!
      end

      expect(transaction).to_not include_events
    end
  end
end
