describe Appsignal::Rack::BodyWrapper do
  # Create the transaction inside the example (lazily, on first reference) and
  # set it as the current transaction. In collector mode it must be created
  # after the mode context's `before` has enabled collector mode, so it gets
  # the OpenTelemetry backend.
  let(:transaction) do
    http_request_transaction.tap { |t| set_current_transaction(t) }
  end

  # Collector-mode assertion helpers. The wrapper does not complete the
  # transaction, so finish it here to export its spans, then assert on the
  # recorded exception events / child event spans.
  def expect_collector_error(type, message)
    transaction.complete
    event = root_span.events.find { |e| e.name == "exception" }
    expect(event).not_to be_nil
    expect(event.attributes["exception.type"]).to eq(type)
    expect(event.attributes["exception.message"]).to eq(message)
    expect(event.attributes["exception.stacktrace"]).to be_a(String)
    expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
    expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
  end

  def expect_collector_no_error
    transaction.complete
    expect(exception_events).to be_empty
  end

  def expect_collector_event(name, title = nil)
    transaction.complete
    # The event name leads the span name. When there is a human-readable
    # title it follows in parentheses, otherwise the name stands alone.
    span = event_span_for(name)
    expect(span).not_to be_nil
    expect(span.parent_span_id).to eq(root_span.span_id)
    expect(span.name).to eq("#{name} (#{title})") if title
  end

  def expect_collector_no_event(name)
    transaction.complete
    expect(event_spans_for(name)).to be_empty
  end

  it_in_both_modes "forwards method calls to the body if the method doesn't exist" do
    fake_body = double(
      :body => ["some body"],
      :some_method => :some_value
    )

    wrapped = described_class.wrap(fake_body, transaction)
    expect(wrapped).to respond_to(:body)
    expect(wrapped.body).to eq(["some body"])

    expect(wrapped).to respond_to(:some_method)
    expect(wrapped.some_method).to eq(:some_value)
  end

  it_in_both_modes "doesn't respond to methods the Rack::BodyProxy doesn't respond to" do
    body = Rack::BodyProxy.new(["body"])
    wrapped = described_class.wrap(body, transaction)

    expect(wrapped).to_not respond_to(:to_str)
    expect { wrapped.to_str }.to raise_error(NoMethodError)

    expect(wrapped).to_not respond_to(:body)
    expect { wrapped.body }.to raise_error(NoMethodError)
  end

  describe "with a body only supporting each()" do
    it_in_both_modes "wraps with appropriate class" do
      fake_body = double(:each => nil)

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to respond_to(:close)
    end

    describe "reads out the body in full using each" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, transaction)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#each)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#each)"
        )
      end
    end

    describe "returns an Enumerator if each() gets called without a block" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, transaction)
        enum = wrapped.each
        expect(enum).to be_kind_of(Enumerator)
        expect { |b| enum.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to_not include_event("name" => "process_response_body.rack")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        transaction.complete

        # Mirrors the agent `to_not include_event` here: that matcher only
        # excludes a *default-shaped* event (empty title). Iterating the
        # returned Enumerator still instruments `each`, so the recorded event
        # carries the "#each" title -- there is just never a title-less one.
        # A title-less event names the span after its category alone, without
        # a parenthesized title; the "#each" one never does.
        titleless_event = event_spans_for("process_response_body.rack").find do |span|
          span.name == "process_response_body.rack"
        end
        expect(titleless_event).to be_nil
      end
    end

    describe "sets the exception raised inside each() on the transaction" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "doesn't report EPIPE error" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(Errno::EPIPE)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(Errno::EPIPE)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "doesn't report ECONNRESET error" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(Errno::ECONNRESET)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(Errno::ECONNRESET)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error when it's the nested error cause" do
      def perform
        error = error_with_nested_cause(StandardError, "error message", Errno::EPIPE)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error when it's the nested error cause" do
      def perform
        error = error_with_nested_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "closes the body and tracks an instrumentation event when it gets closed" do
      def perform
        fake_body = double(:close => nil)
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, transaction)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
        wrapped.close
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event("name" => "close_response_body.rack")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event("close_response_body.rack")
      end
    end

    describe "reports an error if an error occurs on close" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:close).and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.close
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "doesn't report EPIPE error on close" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:close).and_raise(Errno::EPIPE)

        wrapped = described_class.wrap(fake_body, transaction)
        expect { wrapped.close }.to raise_error(Errno::EPIPE)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "doesn't report ECONNRESET error on close" do
      def perform
        fake_body = double
        expect(fake_body).to receive(:close).and_raise(Errno::ECONNRESET)

        wrapped = described_class.wrap(fake_body, transaction)
        expect { wrapped.close }.to raise_error(Errno::ECONNRESET)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error when it's the error cause on close" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        fake_body = double
        expect(fake_body).to receive(:close).and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect { wrapped.close }.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error when it's the error cause on close" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_body = double
        expect(fake_body).to receive(:close).and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect { wrapped.close }.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end
  end

  describe "with a body supporting both each() and call" do
    it_in_both_modes "wraps with the wrapper that exposes each" do
      fake_body = double(
        :each => true,
        :call => "original call"
      )

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to respond_to(:call)
      expect(wrapped.call).to eq("original call")
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end
  end

  describe "with a body supporting both to_ary and each" do
    let(:fake_body) { double(:each => nil, :to_ary => []) }

    it_in_both_modes "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    describe "reads out the body in full using each" do
      def perform
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, transaction)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#each)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#each)"
        )
      end
    end

    describe "sets the exception raised inside each() into the Appsignal transaction" do
      def perform
        expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "doesn't report EPIPE error" do
      def perform
        expect(fake_body).to receive(:each).once.and_raise(Errno::EPIPE)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(Errno::EPIPE)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "doesn't report ECONNRESET error" do
      def perform
        expect(fake_body).to receive(:each).once.and_raise(Errno::ECONNRESET)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(Errno::ECONNRESET)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error when it's the error cause (each)" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error when it's the error cause (each)" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_body = double
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "reads out the body in full using to_ary" do
      def perform
        expect(fake_body).to receive(:to_ary).and_return(["one", "two", "three"])

        wrapped = described_class.wrap(fake_body, transaction)
        expect(wrapped.to_ary).to eq(["one", "two", "three"])
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#to_ary)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#to_ary)"
        )
      end
    end

    describe "sends the exception raised inside to_ary() to AppSignal and closes" do
      def perform
        fake_body = double
        allow(fake_body).to receive(:each)
        expect(fake_body).to receive(:to_ary).once.and_raise(ExampleException, "error message")
        expect(fake_body).to_not receive(:close) # Per spec we expect the body has closed itself

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_ary
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "does not report EPIPE error when it's the error cause (to_ary)" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        fake_body = double
        allow(fake_body).to receive(:each)
        expect(fake_body).to receive(:to_ary).once.and_raise(error)
        expect(fake_body).to_not receive(:close) # Per spec we expect the body has closed itself

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_ary
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error when it's the error cause (to_ary)" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_body = double
        allow(fake_body).to receive(:each)
        expect(fake_body).to receive(:to_ary).once.and_raise(error)
        expect(fake_body).to_not receive(:close) # Per spec we expect the body has closed itself

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_ary
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end
  end

  describe "with a body supporting both to_path and each" do
    let(:fake_body) { double(:each => nil, :to_path => nil) }

    it_in_both_modes "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    describe "reads out the body in full using each()" do
      def perform
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, transaction)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#each)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#each)"
        )
      end
    end

    describe "sets the exception raised inside each() into the Appsignal transaction" do
      def perform
        expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "sets the exception raised inside to_path() into the Appsignal transaction" do
      def perform
        allow(fake_body).to receive(:to_path).once.and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_path
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "doesn't report EPIPE error" do
      def perform
        expect(fake_body).to receive(:to_path).once.and_raise(Errno::EPIPE)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_path
        end.to raise_error(Errno::EPIPE)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "doesn't report ECONNRESET error" do
      def perform
        expect(fake_body).to receive(:to_path).once.and_raise(Errno::ECONNRESET)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_path
        end.to raise_error(Errno::ECONNRESET)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error from #each when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error from #each when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        expect(fake_body).to receive(:each).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          expect { |b| wrapped.each(&b) }.to yield_control
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error from #to_path when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        allow(fake_body).to receive(:to_path).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_path
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error from #to_path when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        allow(fake_body).to receive(:to_path).once.and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.to_path
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "exposes to_path to the sender" do
      def perform
        allow(fake_body).to receive(:to_path).and_return("/tmp/file.bin")

        wrapped = described_class.wrap(fake_body, transaction)
        expect(wrapped.to_path).to eq("/tmp/file.bin")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#to_path)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#to_path)"
        )
      end
    end
  end

  describe "with a body only supporting call()" do
    let(:fake_body) { double(:call => nil) }

    it_in_both_modes "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to_not respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to respond_to(:call)
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    describe "passes the stream into the call() of the body" do
      def perform
        fake_rack_stream = double("stream")
        expect(fake_body).to receive(:call).with(fake_rack_stream)

        wrapped = described_class.wrap(fake_body, transaction)
        wrapped.call(fake_rack_stream)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to include_event(
          "name" => "process_response_body.rack",
          "title" => "Process Rack response body (#call)"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_event(
          "process_response_body.rack",
          "Process Rack response body (#call)"
        )
      end
    end

    describe "sets the exception raised inside call() into the Appsignal transaction" do
      def perform
        fake_rack_stream = double
        allow(fake_body).to receive(:call)
          .with(fake_rack_stream)
          .and_raise(ExampleException, "error message")

        wrapped = described_class.wrap(fake_body, transaction)

        expect do
          wrapped.call(fake_rack_stream)
        end.to raise_error(ExampleException, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform

        expect(transaction).to have_error("ExampleException", "error message")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform

        expect_collector_error("ExampleException", "error message")
      end
    end

    describe "doesn't report EPIPE error" do
      def perform
        fake_rack_stream = double
        expect(fake_body).to receive(:call)
          .with(fake_rack_stream)
          .and_raise(Errno::EPIPE)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.call(fake_rack_stream)
        end.to raise_error(Errno::EPIPE)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "doesn't report ECONNRESET error" do
      def perform
        fake_rack_stream = double
        expect(fake_body).to receive(:call)
          .with(fake_rack_stream)
          .and_raise(Errno::ECONNRESET)

        wrapped = described_class.wrap(fake_body, transaction)
        expect do
          wrapped.call(fake_rack_stream)
        end.to raise_error(Errno::ECONNRESET)
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report EPIPE error from #call when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::EPIPE)
        fake_rack_stream = double
        allow(fake_body).to receive(:call)
          .with(fake_rack_stream)
          .and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)

        expect do
          wrapped.call(fake_rack_stream)
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end

    describe "does not report ECONNRESET error from #call when it's the error cause" do
      def perform
        error = error_with_cause(StandardError, "error message", Errno::ECONNRESET)
        fake_rack_stream = double
        allow(fake_body).to receive(:call)
          .with(fake_rack_stream)
          .and_raise(error)

        wrapped = described_class.wrap(fake_body, transaction)

        expect do
          wrapped.call(fake_rack_stream)
        end.to raise_error(StandardError, "error message")
      end

      it "in agent mode", :agent_mode do
        start_agent

        perform
        expect(transaction).to_not have_error
      end

      it "in collector mode", :collector_mode do
        start_collector_agent

        perform
        expect_collector_no_error
      end
    end
  end

  def error_with_cause(klass, message, cause)
    begin
      raise cause
    rescue
      raise klass, message
    end
  rescue => error
    error
  end

  def error_with_nested_cause(klass, message, cause)
    begin
      begin
        raise cause
      rescue
        raise klass, message
      end
    rescue
      raise klass, message
    end
  rescue => error
    error
  end
end
