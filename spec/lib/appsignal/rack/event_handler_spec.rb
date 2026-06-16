describe Appsignal::Rack::EventHandler do
  let(:queue_start_time) { fixed_time * 1_000 }
  let(:env) do
    {
      "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}", # in milliseconds
      "REQUEST_METHOD" => "POST",
      "PATH_INFO" => "/path",
      "HTTP_ACCEPT" => "application/json",
      "QUERY_STRING" => "query_param1=value1&query_param2=value2",
      "rack.session" => { "session1" => "value1", "session2" => "value2" },
      "rack.input" => StringIO.new("post_param1=value1&post_param2=value2")
    }
  end
  let(:request) { Rack::Request.new(env) }
  let(:response) { nil }
  let(:log_stream) { StringIO.new }
  let(:logs) { log_contents(log_stream) }
  let(:event_handler_instance) do
    described_class.new.tap do |handler|
      # Silence deprecation warning about using it with the `Rack::Events`
      # middleware, instead of through `Appsignal::Rack::EventMiddleware`,
      # which uses `Appsignal::Rack::Events` under the hood.
      handler.using_appsignal_event_middleware = true
    end
  end
  let(:rack_app) { lambda { |_env| [200, {}, ["Hello world!"]] } }
  let(:appsignal_env) { :default }
  # Pass the example's AppSignal env through to the mode contexts' `start_agent`.
  let(:start_agent_args) { { :env => appsignal_env } }

  # `start_agent` resets the internal logger, so the test logger has to be
  # installed from the example body, after the mode context starts the agent.
  def use_test_logger
    Appsignal.internal_logger = test_logger(log_stream)
  end

  def on_start
    event_handler_instance.on_start(request, response)
  end

  def on_error(error)
    event_handler_instance.on_error(request, response, error)
  end

  context "when used with ::Rack::Events" do
    # Do not silence the deprecation warning about using it with the
    # `Rack::Events` middleware.
    let(:event_handler_instance) { described_class.new }

    it_in_both_modes "emits a warning about using it with Rack::Events" do
      use_test_logger
      events = ::Rack::Events.new(rack_app, [event_handler_instance])

      logs = capture_logs { events.call({}) }
      expect(logs).to contains_log(
        :warn,
        /Rack::Events is not compatible with streaming bodies./
      )
    end
  end

  context "When used via ::Appsignal::Rack::EventMiddleware" do
    it_in_both_modes "does not emit a warning about using it with Rack::Events" do
      use_test_logger
      expect(described_class).to receive(:new).and_call_original

      event_middleware = Appsignal::Rack::EventMiddleware.new(rack_app)

      logs = capture_logs { event_middleware.call({}) }
      expect(logs).to_not contains_log(
        :warn,
        /Rack::Events is not compatible with streaming bodies./
      )
    end
  end

  describe "#on_start" do
    describe "creates a new transaction" do
      def perform
        on_start
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        expect { perform }.to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(transaction).to have_id
        expect(transaction).to have_namespace(Appsignal::Transaction::HTTP_REQUEST)

        expect(Appsignal::Transaction.current).to eq(transaction)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        expect { perform }.to change { created_transactions.length }.by(1)

        transaction = last_transaction
        expect(Appsignal::Transaction.current).to eq(transaction)
        # Finish the still-open root span so we can read the namespace it was
        # opened with.
        Appsignal::Transaction.complete_current!
        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::HTTP_REQUEST)
        expect(root_span.kind).to eq(:server)
      end
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      it_in_both_modes "does not create a new transaction" do
        use_test_logger
        expect { on_start }.to_not(change { created_transactions.length })
      end
    end

    context "when the handler is nested in another EventHandler" do
      it_in_both_modes "does not create a new transaction in the nested EventHandler" do
        use_test_logger
        on_start
        expect { described_class.new.on_start(request, response) }
          .to_not(change { created_transactions.length })
      end
    end

    it_in_both_modes "registers transaction on the request environment" do
      use_test_logger
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to eq(last_transaction)
    end

    describe "registers an rack.after_reply callback that completes the transaction" do
      def perform
        request.env[Appsignal::Rack::RACK_AFTER_REPLY] = []
        expect do
          on_start
        end.to change { request.env[Appsignal::Rack::RACK_AFTER_REPLY].length }.by(1)

        expect(Appsignal::Transaction.current).to eq(last_transaction)

        callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
        callback.call

        expect(Appsignal::Transaction.current).to be_kind_of(Appsignal::Transaction::NilTransaction)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction.backend.queue_start).to eq(queue_start_time)
        expect(last_transaction).to include_event(
          "name" => "process_request.rack",
          "title" => "callback: after_reply"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        queue_event = Array(root_span.events).find { |e| e.name == "appsignal.queue_start" }
        expect(queue_event.attributes["appsignal.queue_start"]).to eq(queue_start_time.to_i)
        event = event_spans.find do |span|
          span.attributes["appsignal.category"] == "process_request.rack"
        end
        expect(event).not_to be_nil
        expect(event.parent_span_id).to eq(root_span.span_id)
        expect(event.name).to eq("callback: after_reply")
      end
    end

    context "with error inside rack.after_reply handler" do
      def trigger_after_reply_error
        on_start
        # A random spot we can access to raise an error for this test
        expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
          .to receive(:finish_event)
          .and_raise(ExampleStandardError, "oh no")
        callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
        callback.call
      end

      it_in_both_modes "completes the transaction" do
        use_test_logger
        trigger_after_reply_error

        expect(last_transaction).to be_completed
      end

      it_in_both_modes "logs an error" do
        use_test_logger
        trigger_after_reply_error

        expect(logs).to contains_log(
          :error,
          "Error occurred in Appsignal::Rack::EventHandler's after_reply: " \
            "ExampleStandardError: oh no"
        )
      end
    end

    it_in_both_modes "logs errors from rack.after_reply callbacks" do
      use_test_logger
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to receive(:finish_event)
        .and_raise(ExampleStandardError, "oh no")
      callback = request.env[Appsignal::Rack::RACK_AFTER_REPLY].first
      callback.call

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler's after_reply: ExampleStandardError: oh no"
      )
    end

    it_in_both_modes "logs an error in case of an error" do
      use_test_logger
      expect(Appsignal::Transaction)
        .to receive(:create).and_raise(ExampleStandardError, "oh no")

      on_start

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_start: ExampleStandardError: oh no"
      )
    end
  end

  describe "#on_error" do
    describe "reports the error" do
      def perform
        on_start
        on_error(ExampleStandardError.new("the error"))
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to have_error("ExampleStandardError", "the error")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform
        # The error is recorded on the still-open span; finish it so the
        # exception event exports.
        Appsignal::Transaction.complete_current!

        # The error is set while the `process_request.rack` event span is the
        # current span (on_start opens it; it is not finished before on_error),
        # so the exception event rides on that event span, not the root span.
        error_span = span_exporter.finished_spans.find do |span|
          Array(span.events).any? { |e| e.name == "exception" }
        end
        expect(error_span).not_to be_nil
        event = error_span.events.find { |e| e.name == "exception" }
        expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
        expect(event.attributes["exception.message"]).to eq("the error")
        expect(event.attributes["exception.stacktrace"]).to be_a(String)
        expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
        expect(error_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
      end
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      describe "does not report the transaction" do
        def perform
          on_start
          on_error(ExampleStandardError.new("the error"))
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not have_error
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(exception_events).to be_empty
        end
      end
    end

    context "when the handler is nested in another EventHandler" do
      describe "does not report the error on the transaction" do
        def perform
          on_start
          described_class.new.on_error(request, response, ExampleStandardError.new("the error"))
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not have_error
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform
          Appsignal::Transaction.complete_current!

          expect(exception_events).to be_empty
        end
      end
    end

    it_in_both_modes "logs an error in case of an internal error" do
      use_test_logger
      on_start

      expect(request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION])
        .to receive(:set_error).and_raise(ExampleStandardError, "oh no")

      on_error(ExampleStandardError.new("the error"))

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_error: ExampleStandardError: oh no"
      )
    end
  end

  describe "#on_finish" do
    let(:response) { Rack::Events::BufferedResponse.new(200, {}, ["body"]) }

    def on_finish(given_request = request, given_response = response)
      event_handler_instance.on_finish(given_request, given_response)
    end

    describe "doesn't do anything without a transaction" do
      def perform
        on_start
        request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = nil
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to_not have_action
        expect(last_transaction).to_not include_events
        expect(last_transaction).to include("sample_data" => {})
        expect(last_transaction).to_not be_completed
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        expect(last_transaction).to_not be_completed
        expect(root_span).to be_nil
        expect(event_spans).to be_empty
      end
    end

    context "when not active" do
      let(:appsignal_env) { :inactive_env }

      describe "doesn't do anything" do
        def perform
          request.env[Appsignal::Rack::APPSIGNAL_TRANSACTION] = http_request_transaction
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not have_action
          expect(last_transaction).to_not include_events
          expect(last_transaction).to include("sample_data" => {})
          expect(last_transaction).to_not be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(last_transaction).to_not be_completed
          expect(event_spans).to be_empty
        end
      end
    end

    describe "sets params on the transaction" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to include_params(
          "query_param1" => "value1",
          "query_param2" => "value2",
          "post_param1" => "value1",
          "post_param2" => "value2"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        params = JSON.parse(root_span.attributes["appsignal.request.payload"])
        expect(params).to include(
          "query_param1" => "value1",
          "query_param2" => "value2",
          "post_param1" => "value1",
          "post_param2" => "value2"
        )
      end
    end

    describe "sets headers on the transaction" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to include_environment(
          "REQUEST_METHOD" => "POST",
          "PATH_INFO" => "/path"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        # Only true HTTP headers map to `http.request.header.*`; the CGI vars
        # REQUEST_METHOD/PATH_INFO are intentionally dropped.
        expect(root_span.attributes["http.request.header.accept"]).to eq("application/json")
        expect(root_span.attributes.keys).to_not include("http.request.header.request-method")
      end
    end

    describe "sets session data on the transaction" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to include_session_data(
          "session1" => "value1",
          "session2" => "value2"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        session = JSON.parse(root_span.attributes["appsignal.request.session_data"])
        expect(session).to include(
          "session1" => "value1",
          "session2" => "value2"
        )
      end
    end

    describe "sets the queue start time on the transaction" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to have_queue_start(queue_start_time)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        # `set_queue_start` is an intentional no-op in collector mode.
        expect(last_transaction).to_not have_queue_start
      end
    end

    describe "completes the transaction" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to_not have_action
        expect(last_transaction).to be_completed
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        expect(root_span.attributes).to_not have_key("appsignal.action_name")
        expect(last_transaction).to be_completed
      end
    end

    context "without a response" do
      describe "sets params on the transaction" do
        def perform
          on_start
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to include_params(
            "query_param1" => "value1",
            "query_param2" => "value2",
            "post_param1" => "value1",
            "post_param2" => "value2"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          params = JSON.parse(root_span.attributes["appsignal.request.payload"])
          expect(params).to include(
            "query_param1" => "value1",
            "query_param2" => "value2",
            "post_param1" => "value1",
            "post_param2" => "value2"
          )
        end
      end

      describe "sets headers on the transaction" do
        def perform
          on_start
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to include_environment(
            "REQUEST_METHOD" => "POST",
            "PATH_INFO" => "/path"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(root_span.attributes["http.request.header.accept"]).to eq("application/json")
          expect(root_span.attributes.keys).to_not include("http.request.header.request-method")
        end
      end

      describe "sets session data on the transaction" do
        def perform
          on_start
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to include_session_data(
            "session1" => "value1",
            "session2" => "value2"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          session = JSON.parse(root_span.attributes["appsignal.request.session_data"])
          expect(session).to include(
            "session1" => "value1",
            "session2" => "value2"
          )
        end
      end

      describe "sets the queue start time on the transaction" do
        def perform
          on_start
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to have_queue_start(queue_start_time)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(last_transaction).to_not have_queue_start
        end
      end

      describe "completes the transaction" do
        # The action is not set on purpose, as we can't set a normalized route.
        # It requires the app to set an action name.
        def perform
          on_start
          on_finish(request, nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not have_action
          expect(last_transaction).to be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(root_span.attributes).to_not have_key("appsignal.action_name")
          expect(last_transaction).to be_completed
        end
      end

      describe "does not set a response_status tag" do
        def perform
          on_start
          on_finish(request, nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not include_tags("response_status" => anything)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(root_span.attributes.keys).to_not include("appsignal.tag.response_status")
        end
      end

      describe "does not report a response_status counter metric" do
        def perform
          on_start
          on_finish(request, nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          expect(Appsignal).to_not receive(:increment_counter)
            .with(:response_status, anything, anything)

          perform
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(metric_snapshot("response_status")).to be_nil
        end
      end

      context "with an error previously recorded by on_error" do
        describe "sets response status 500 as a tag" do
          def perform
            on_start
            on_error(ExampleStandardError.new("the error"))
            on_finish(request, nil)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            use_test_logger
            perform

            expect(last_transaction).to include_tags("response_status" => 500)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            use_test_logger
            perform

            expect(root_span.attributes["appsignal.tag.response_status"]).to eq(500)
          end
        end

        describe "increments the response status counter for response status 500" do
          def perform
            on_start
            on_error(ExampleStandardError.new("the error"))
            on_finish(request, nil)
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            use_test_logger
            expect(Appsignal).to receive(:increment_counter)
              .with(:response_status, 1, :status => 500, :namespace => :web)

            perform
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            use_test_logger
            perform

            snapshot = metric_snapshot("response_status")
            expect(snapshot).not_to be_nil
            expect(snapshot.data_points.first.value).to eq(1.0)
            expect(snapshot.data_points.first.attributes).to eq(
              "status" => 500,
              "namespace" => "web"
            )
          end
        end
      end
    end

    context "with error inside on_finish handler" do
      def trigger_on_finish_error
        on_start
        # A random spot we can access to raise an error for this test
        expect(Appsignal).to receive(:increment_counter).and_raise(ExampleStandardError, "oh no")
        on_finish
      end

      it_in_both_modes "completes the transaction" do
        use_test_logger
        trigger_on_finish_error

        expect(last_transaction).to be_completed
      end

      it_in_both_modes "logs an error" do
        use_test_logger
        trigger_on_finish_error

        expect(logs).to contains_log(
          :error,
          "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
        )
      end
    end

    context "when the handler is nested in another EventHandler" do
      describe "does not complete the transaction" do
        def perform
          on_start
          described_class.new.on_finish(request, response)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to_not have_action
          expect(last_transaction).to_not include_metadata
          expect(last_transaction).to_not include_events
          expect(last_transaction.to_h).to include("sample_data" => {})
          expect(last_transaction).to_not be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(last_transaction).to_not be_completed
          expect(root_span).to be_nil
          expect(event_spans).to be_empty
        end
      end
    end

    describe "doesn't set the action name if already set" do
      def perform
        on_start
        last_transaction.set_action("My action")
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to have_action("My action")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        expect(root_span.name).to eq("My action")
        expect(root_span.attributes["appsignal.action_name"]).to eq("My action")
      end
    end

    describe "finishes the process_request.rack event" do
      def perform
        on_start
        on_finish
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        use_test_logger
        perform

        expect(last_transaction).to include_event(
          "name" => "process_request.rack",
          "title" => "callback: on_finish"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        use_test_logger
        perform

        event = event_spans.find do |span|
          span.attributes["appsignal.category"] == "process_request.rack"
        end
        expect(event).not_to be_nil
        expect(event.parent_span_id).to eq(root_span.span_id)
        expect(event.name).to eq("callback: on_finish")
      end
    end

    context "with response" do
      describe "sets the response status as a tag" do
        def perform
          on_start
          on_finish
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          use_test_logger
          perform

          expect(last_transaction).to include_tags("response_status" => 200)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          use_test_logger
          perform

          expect(root_span.attributes["appsignal.tag.response_status"]).to eq(200)
        end
      end

      context "with an error previously recorded by on_error" do
        describe "sets response status from the response as a tag" do
          def perform
            on_start
            on_error(ExampleStandardError.new("the error"))
            on_finish
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            use_test_logger
            perform

            expect(last_transaction).to include_tags("response_status" => 200)
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            use_test_logger
            perform

            expect(root_span.attributes["appsignal.tag.response_status"]).to eq(200)
          end
        end

        describe "increments the response status counter based on the response" do
          def perform
            on_start
            on_error(ExampleStandardError.new("the error"))
            on_finish
          end

          it "in agent mode", :agent_mode do
            start_agent(**start_agent_args)
            use_test_logger
            expect(Appsignal).to receive(:increment_counter)
              .with(:response_status, 1, :status => 200, :namespace => :web)

            perform
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            use_test_logger
            perform

            snapshot = metric_snapshot("response_status")
            expect(snapshot).not_to be_nil
            expect(snapshot.data_points.first.value).to eq(1.0)
            expect(snapshot.data_points.first.attributes).to eq(
              "status" => 200,
              "namespace" => "web"
            )
          end
        end
      end
    end

    it_in_both_modes "logs an error in case of an error" do
      use_test_logger
      # A random spot we can access to raise an error for this test
      expect(Appsignal).to receive(:increment_counter).and_raise(ExampleStandardError, "oh no")

      on_start
      on_finish

      expect(logs).to contains_log(
        :error,
        "Error occurred in Appsignal::Rack::EventHandler#on_finish: ExampleStandardError: oh no"
      )
    end
  end
end

# Separate top-level describe so it doesn't inherit the parameterized
# `before { start_agent(:env => appsignal_env) }` above (which would clobber
# collector mode); `start_agent` comes from the mode contexts. The agent has no
# in-memory metric readout, so agent mode keeps the `increment_counter` mock
# while collector mode asserts the counter reaches the OpenTelemetry backend.
describe Appsignal::Rack::EventHandler, "response status counter" do
  let(:env) do
    {
      "REQUEST_METHOD" => "GET",
      "PATH_INFO" => "/path",
      "rack.input" => StringIO.new("")
    }
  end
  let(:request) { Rack::Request.new(env) }
  let(:response) { Rack::Events::BufferedResponse.new(200, {}, ["body"]) }
  let(:event_handler_instance) do
    described_class.new.tap do |handler|
      handler.using_appsignal_event_middleware = true
    end
  end

  describe "for a successful request" do
    def perform
      event_handler_instance.on_start(request, response)
      event_handler_instance.on_finish(request, response)
    end

    it "in agent mode", :agent_mode do
      start_agent

      expect(Appsignal).to receive(:increment_counter)
        .with(:response_status, 1, :status => 200, :namespace => :web)

      perform
    end

    it "in collector mode", :collector_mode do
      start_collector_agent

      perform

      snapshot = metric_snapshot("response_status")
      expect(snapshot).not_to be_nil
      expect(snapshot.data_points.first.value).to eq(1.0)
      expect(snapshot.data_points.first.attributes).to eq(
        "status" => 200,
        "namespace" => "web"
      )
    end
  end

  describe "for a request that errors" do
    # No response, and an error recorded by `on_error`, so the status comes
    # from the error (500) rather than the response.
    def perform
      event_handler_instance.on_start(request, response)
      event_handler_instance.on_error(request, response, ExampleStandardError.new("the error"))
      event_handler_instance.on_finish(request, nil)
    end

    it "in agent mode", :agent_mode do
      start_agent

      expect(Appsignal).to receive(:increment_counter)
        .with(:response_status, 1, :status => 500, :namespace => :web)

      perform
    end

    it "in collector mode", :collector_mode do
      start_collector_agent

      perform

      snapshot = metric_snapshot("response_status")
      expect(snapshot).not_to be_nil
      expect(snapshot.data_points.first.value).to eq(1.0)
      expect(snapshot.data_points.first.attributes).to eq(
        "status" => 500,
        "namespace" => "web"
      )
    end
  end
end
