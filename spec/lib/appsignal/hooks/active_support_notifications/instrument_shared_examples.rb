shared_examples "activesupport instrument override" do
  it "instruments an ActiveSupport::Notifications.instrument event" do
    return_value = as.instrument("sql.active_record", :sql => "SQL") do
      "value"
    end

    expect(return_value).to eq "value"
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

  it "instruments an ActiveSupport::Notifications.instrument event with no registered formatter" do
    return_value = as.instrument("no-registered.formatter", :key => "something") do
      "value"
    end

    expect(return_value).to eq "value"
    expect(transaction.to_h["events"]).to match([
      {
        "allocation_count" => kind_of(Integer),
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "child_allocation_count" => kind_of(Integer),
        "child_duration" => kind_of(Float),
        "child_gc_duration" => kind_of(Float),
        "count" => 1,
        "duration" => kind_of(Float),
        "gc_duration" => kind_of(Float),
        "name" => "no-registered.formatter",
        "start" => kind_of(Float),
        "title" => ""
      }
    ])
  end

  it "converts non-string names to strings" do
    as.instrument(:not_a_string) {} # rubocop:disable Lint/EmptyBlock
    expect(transaction.to_h["events"]).to match([
      {
        "allocation_count" => kind_of(Integer),
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "child_allocation_count" => kind_of(Integer),
        "child_duration" => kind_of(Float),
        "child_gc_duration" => kind_of(Float),
        "count" => 1,
        "duration" => kind_of(Float),
        "gc_duration" => kind_of(Float),
        "name" => "not_a_string",
        "start" => kind_of(Float),
        "title" => ""
      }
    ])
  end

  it "does not instrument events whose name starts with a bang" do
    expect(Appsignal::Transaction.current).not_to receive(:start_event)
    expect(Appsignal::Transaction.current).not_to receive(:finish_event)

    return_value = as.instrument("!sql.active_record", :sql => "SQL") do
      "value"
    end

    expect(return_value).to eq "value"
  end

  context "when an error is raised in an instrumented block" do
    it "instruments an ActiveSupport::Notifications.instrument event" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")

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
  end

  context "when a message is thrown in an instrumented block" do
    it "instruments an ActiveSupport::Notifications.instrument event" do
      expect do
        as.instrument("sql.active_record", :sql => "SQL") do
          throw :foo
        end
      end.to throw_symbol(:foo)

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
  end

  context "when a transaction is completed in an instrumented block" do
    it "does not complete the ActiveSupport::Notifications.instrument event" do
      expect(transaction).to receive(:complete)
      as.instrument("sql.active_record", :sql => "SQL") do
        Appsignal::Transaction.complete_current!
      end

      expect(transaction.to_h["events"]).to match([])
    end
  end
end
