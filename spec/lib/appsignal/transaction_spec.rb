describe Appsignal::Transaction do
  let(:options) { {} }
  let(:time) { Time.at(fixed_time) }
  let(:root_path) { nil }

  before do |example|
    # Only auto-start the agent for non-mode examples. Mode-tagged examples
    # (`:agent_mode`/`:collector_mode`) start the agent themselves in their body
    # (agent mode via `start_agent(**start_agent_args)`, collector mode via
    # `start_collector_agent`) -- the dual-mode start principle -- so starting it
    # here too would clobber the collector setup / leave the test in agent mode.
    unless example.metadata[:agent_mode] || example.metadata[:collector_mode]
      start_agent(:options => options, :root_path => root_path)
    end
    Timecop.freeze(time)
  end

  # Mode-tagged examples start the agent in their body; expose the same
  # `:options`/`:root_path` the automatic start above would have used.
  let(:start_agent_args) { { :options => options, :root_path => root_path } }
  after { Timecop.return }
  around do |example|
    keep_transactions do
      example.run
    end
  end

  describe ".create" do
    context "when no transaction is running" do
      it "returns the created transaction" do
        mock_transaction_id = "mock-uuid"
        allow(SecureRandom).to receive(:uuid).and_return(mock_transaction_id)

        transaction = create_transaction
        expect(transaction).to be_a Appsignal::Transaction

        expect(transaction).to have_id(mock_transaction_id)
        expect(transaction.transaction_id).to eq(mock_transaction_id)

        expect(transaction).to have_namespace(default_namespace)
        expect(transaction.namespace).to eq(default_namespace)
      end

      it "assigns the transaction to current" do
        transaction = create_transaction
        expect(transaction).to eq current_transaction
      end
    end

    context "when an explicit backend is passed in the initialiser" do
      let(:backend) { "some_backend" }

      it "assigns the backend to the transaction" do
        expect(described_class.new("web", :backend => backend).backend).to be(backend)
      end
    end

    context "when a transaction is already running" do
      before do
        allow(SecureRandom).to receive(:uuid)
          .and_return(
            "transaction_id_1",
            "transaction_id_2"
          )
        create_transaction
      end

      it "does not create a new transaction, but returns the current transaction" do
        expect do
          new_transaction = create_transaction

          expect(new_transaction).to eq(current_transaction)
        end.to_not(change { current_transaction })
      end

      it "logs a debug message" do
        logs = capture_logs { create_transaction }

        expect(logs).to contains_log :warn,
          "Trying to start new transaction, but a transaction with id " \
            "'transaction_id_1' is already running. " \
            "Using transaction 'transaction_id_1'."
      end
    end

    context "when a completed transaction is still in Thread.current" do
      before do
        allow(SecureRandom).to receive(:uuid)
          .and_return(
            "transaction_id_1",
            "transaction_id_2"
          )
        transaction = create_transaction
        transaction.complete
      end

      it "creates a new transaction instead of reusing the completed one" do
        new_transaction = create_transaction

        expect(new_transaction.transaction_id).to eq("transaction_id_2")
        expect(new_transaction).to eq(current_transaction)
        expect(new_transaction).to_not be_completed
      end

      it "clears the completed transaction from Thread.current" do
        expect(Thread.current[:appsignal_transaction]).to be_completed

        create_transaction

        expect(current_transaction.transaction_id).to eq("transaction_id_2")
      end
    end

    describe "transaction state after create" do
      it_in_both_modes do
        transaction = create_transaction
        expect(transaction.namespace).to eq(Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction.transaction_id).to be_a(String)
        expect(transaction.transaction_id).not_to be_empty
      end
    end

    describe "OpenTelemetry root span" do
      it "starts a root span with SpanKind::SERVER for HTTP_REQUEST", :collector_mode do
        start_collector_agent
        create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        Appsignal::Transaction.complete_current!

        expect(span_exporter.finished_spans.size).to eq(1)
        span = span_exporter.finished_spans.first
        expect(span.kind).to eq(:server)
        expect(span.name).to eq("appsignal.transaction http_request")
      end

      it "uses SpanKind::CONSUMER for BACKGROUND_JOB", :collector_mode do
        start_collector_agent
        create_transaction(Appsignal::Transaction::BACKGROUND_JOB)
        Appsignal::Transaction.complete_current!

        expect(span_exporter.finished_spans.first.kind).to eq(:consumer)
      end

      it "uses SpanKind::SERVER for ACTION_CABLE", :collector_mode do
        start_collector_agent
        create_transaction(Appsignal::Transaction::ACTION_CABLE)
        Appsignal::Transaction.complete_current!

        expect(span_exporter.finished_spans.first.kind).to eq(:server)
      end

      it "uses SpanKind::SERVER for an unknown custom namespace", :collector_mode do
        start_collector_agent
        create_transaction("my_custom_namespace")
        Appsignal::Transaction.complete_current!

        span = span_exporter.finished_spans.first
        expect(span.kind).to eq(:server)
        expect(span.name).to eq("appsignal.transaction my_custom_namespace")
      end
    end

    describe "OpenTelemetry current context" do
      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)

        create_transaction(Appsignal::Transaction::HTTP_REQUEST)

        expect(::OpenTelemetry::Trace.current_span).not_to eq(::OpenTelemetry::Trace::Span::INVALID)
        expect(::OpenTelemetry::Trace.current_span.context.trace_id).not_to be_nil

        Appsignal::Transaction.complete_current!

        expect(::OpenTelemetry::Trace.current_span).to eq(::OpenTelemetry::Trace::Span::INVALID)
      end
    end
  end

  describe ".current" do
    context "when there is a current transaction" do
      let!(:transaction) { create_transaction }

      it "reads :appsignal_transaction from the current Thread" do
        expect(current_transaction).to eq(Thread.current[:appsignal_transaction])
        expect(current_transaction).to eq(transaction)
      end

      it "is not a NilTransaction" do
        expect(current_transaction.nil_transaction?).to be(false)
        expect(current_transaction).to be_a(Appsignal::Transaction)
      end

      it "returns true for current?" do
        expect(Appsignal::Transaction.current?).to be(true)
      end
    end

    context "when there is no current transaction" do
      it "has no :appsignal_transaction registered on the current Thread" do
        expect(Thread.current[:appsignal_transaction]).to be_nil
      end

      it "returns a NilTransaction stub" do
        expect(current_transaction.nil_transaction?).to be(true)
        expect(current_transaction).to be_a(Appsignal::Transaction::NilTransaction)
      end

      it "returns false for current?" do
        expect(Appsignal::Transaction.current?).to be(false)
      end
    end
  end

  describe ".complete_current!" do
    context "with active transaction" do
      let!(:transaction) { create_transaction }

      it "completes the current transaction" do
        expect(transaction).to eq(current_transaction)

        Appsignal::Transaction.complete_current!

        expect(transaction).to be_completed
      end

      it "unsets the current transaction on the current Thread" do
        expect do
          Appsignal::Transaction.complete_current!
        end.to change { Thread.current[:appsignal_transaction] }.from(transaction).to(nil)
      end

      context "when encountering an error while completing" do
        before do
          expect(transaction).to receive(:complete).and_raise ExampleStandardError
        end

        it "logs an error message" do
          logs =
            capture_logs do
              Appsignal::Transaction.complete_current!
            end
          expect(logs).to contains_log :error,
            "Failed to complete transaction ##{transaction.transaction_id}. ExampleStandardError"
        end

        it "clears the current transaction" do
          expect do
            Appsignal::Transaction.complete_current!
          end.to change { Thread.current[:appsignal_transaction] }.from(transaction).to(nil)
        end
      end
    end

    context "without active transaction" do
      it "does nothing" do
        expect do
          Appsignal::Transaction.complete_current!
        end.to_not(change { Thread.current[:appsignal_transaction] })
      end
    end

    describe "current transaction after complete_current!" do
      it_in_both_modes do
        create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        Appsignal::Transaction.complete_current!

        expect(Appsignal::Transaction.current).to be_a(Appsignal::Transaction::NilTransaction)
        expect(Appsignal::Transaction.current?).to be(false)
      end
    end
  end

  describe "#complete" do
    let(:transaction) { create_transaction }

    context "when transaction is being sampled" do
      it "samples data" do
        transaction.add_tags(:foo => "bar")
        keep_transactions { transaction.complete }
        expect(transaction).to include_tags("foo" => "bar")
      end
    end

    context "when transaction is not being sampled" do
      it "does not sample data" do
        keep_transactions(:sample => false) { transaction.complete }
        expect(transaction.to_h["sample_data"]).to be_empty
      end
    end

    context "when a transaction is marked as discarded" do
      it "marks the transaction as discarded" do
        expect do
          transaction.discard!
        end.to change { transaction.discarded? }.from(false).to(true)
      end

      it "logs a debug message" do
        allow(SecureRandom).to receive(:uuid).and_return("mock_transaction_id")
        transaction.discard!
        logs = capture_logs { transaction.complete }

        expect(logs).to contains_log :debug,
          "Skipping transaction 'mock_transaction_id' because it was manually discarded."
      end

      describe "completing a discarded transaction" do
        def perform
          transaction.discard!
          transaction.complete
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          # Nothing is reported: the transaction is dropped, not completed.
          expect(transaction).to_not be_completed
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          # The root span is still finished and exported, but flagged so the
          # collector ignores the whole subtrace.
          expect(root_span.attributes["appsignal.ignore_subtrace"]).to be(true)
          # The discarded transaction's context is detached -- it does not leak
          # as the thread's current OTel span.
          expect(::OpenTelemetry::Trace.current_span)
            .to eq(::OpenTelemetry::Trace::Span::INVALID)
        end
      end

      context "when a discarded transaction is restored" do
        it "unmarks the transaction as discarded" do
          transaction.discard!

          expect do
            transaction.restore!
          end.to change { transaction.discarded? }.from(true).to(false)
        end

        describe "completing a restored transaction" do
          def perform
            transaction.discard!
            transaction.restore!
            transaction.complete
          end

          it "in agent mode", :agent_mode do
            start_agent
            perform

            expect(transaction).to be_completed
          end

          it "in collector mode", :collector_mode do
            start_collector_agent
            perform

            # The transaction is reported as normal: the root span is exported
            # without the ignore flag, so the collector keeps the subtrace.
            expect(transaction).to be_completed
            expect(root_span).not_to be_nil
            expect(root_span.attributes).not_to have_key("appsignal.ignore_subtrace")
          end
        end
      end
    end

    context "when a transaction has errors" do
      let(:error) do
        ExampleStandardError.new("test message").tap do |e|
          e.set_backtrace(["line 1"])
        end
      end

      let(:other_error) do
        ExampleStandardError.new("other test message").tap do |e|
          e.set_backtrace(["line 2"])
        end
      end

      context "when an error is already set on the transaction" do
        it "reports errors as duplicate transactions" do
          transaction.set_error(error)
          transaction.add_error(other_error)

          expect do
            transaction.complete
          end.to change { created_transactions.count }.from(1).to(2)

          original_transaction, duplicate_transaction = created_transactions

          expect(original_transaction).to have_error(
            "ExampleStandardError",
            "test message",
            ["line 1"]
          )
          expect(original_transaction).to be_completed

          expect(duplicate_transaction).to have_error(
            "ExampleStandardError",
            "other test message",
            ["line 2"]
          )
          expect(duplicate_transaction).to be_completed
        end
      end

      context "when no error is set on the transaction" do
        it "reports the first error in the original transaction" do
          transaction.add_error(error)
          transaction.add_error(other_error)

          expect do
            transaction.complete
          end.to change { created_transactions.count }.from(1).to(2)

          original_transaction, duplicate_transaction = created_transactions

          expect(original_transaction).to have_error(
            "ExampleStandardError",
            "test message",
            ["line 1"]
          )
          expect(original_transaction).to be_completed

          expect(duplicate_transaction).to have_error(
            "ExampleStandardError",
            "other test message",
            ["line 2"]
          )
          expect(duplicate_transaction).to be_completed
        end
      end

      it "stores the last reported errors" do
        transaction.add_error(error)
        transaction.add_error(other_error)
        transaction.complete

        expect(Appsignal::Transaction.last_errors).to contain_exactly(error, other_error)
      end

      describe "metadata" do
        let(:tags) { { "tag" => "value" } }
        let(:params) { { "param" => "value" } }
        let(:headers) { { "REQUEST_METHOD" => "value" } }
        let(:session_data) { { "session_data" => "value" } }
        let(:custom_data) { { "custom_data" => "value" } }
        before do
          transaction.set_namespace("My namespace")
          transaction.set_action("My action")
          transaction.set_metadata("path", "/some/path")
          transaction.set_metadata("method", "GET")
          transaction.add_tags(tags)
          transaction.add_params(params)
          transaction.add_headers(headers)
          transaction.add_session_data(session_data)
          transaction.add_custom_data(custom_data)
          transaction.add_breadcrumb("category", "action", "message", { "meta" => "data" })

          transaction.start_event
          transaction.finish_event("name", "title", "body", 1)

          transaction.add_error(error)
          transaction.add_error(other_error)

          transaction.complete
        end

        it "copies the transaction metadata and sample data on the duplicate transaction" do
          original_transaction, duplicate_transaction = created_transactions

          duplicate_hash = duplicate_transaction.to_h.tap do |h|
            h.delete("id")
            h.delete("error")
          end
          original_hash = original_transaction.to_h.tap do |h|
            h.delete("id")
            h.delete("error")
          end
          expect(duplicate_hash).to eq(original_hash)
        end

        it "the duplicate transaction has a different transaction id" do
          original_transaction, duplicate_transaction = created_transactions

          expect(original_transaction.transaction_id)
            .to_not eq(duplicate_transaction.transaction_id)
        end

        it "the duplicate transaction has a different extension transaction than the original" do
          original_transaction, duplicate_transaction = created_transactions

          expect(original_transaction.backend).to_not eq(duplicate_transaction.backend)
        end

        it "marks transaction as duplicate on the duplicate transaction" do
          original_transaction, duplicate_transaction = created_transactions

          expect(original_transaction.duplicate?).to be(false)
          expect(duplicate_transaction.duplicate?).to be(true)
        end
      end

      it "merges sample data from the original transaction in the duplicate transaction" do
        transaction.add_tags("root" => "tag")
        transaction.add_params("root" => "param")
        transaction.add_session_data("root" => "session")
        transaction.add_headers("REQUEST_METHOD" => "root")
        transaction.add_custom_data("root" => "custom")
        transaction.add_breadcrumb("root", "breadcrumb")
        Appsignal.report_error(error) do |t|
          t.add_tags("original" => "tag")
          t.add_params("original" => "param")
          t.add_session_data("original" => "session")
          t.add_headers("REQUEST_PATH" => "/original")
          t.add_custom_data("original" => "custom")
          t.add_breadcrumb("original", "breadcrumb")
        end
        Appsignal.report_error(other_error) do |t|
          t.add_tags("duplicate" => "tag")
          t.add_params("duplicate" => "param")
          t.add_session_data("duplicate" => "session")
          t.add_headers("HTTP_ACCEPT" => "duplicate")
          t.add_custom_data("duplicate" => "custom")
          t.add_breadcrumb("duplicate", "breadcrumb")
        end
        transaction.add_tags("root2" => "tag")
        transaction.add_params("root2" => "param")
        transaction.add_session_data("root2" => "session")
        transaction.add_headers("PATH_INFO" => "/root2")
        transaction.add_custom_data("root2" => "custom")
        transaction.add_breadcrumb("root2", "breadcrumb")
        transaction.complete

        original_transaction, duplicate_transaction = created_transactions
        # Original
        expect(original_transaction).to include_tags(
          "root" => "tag",
          "original" => "tag",
          "root2" => "tag"
        )
        expect(original_transaction).to_not include_tags("duplicate" => anything)
        expect(original_transaction).to include_params(
          "root" => "param",
          "original" => "param",
          "root2" => "param"
        )
        expect(original_transaction).to_not include_params("duplicate" => anything)
        expect(original_transaction).to include_session_data(
          "root" => "session",
          "original" => "session",
          "root2" => "session"
        )
        expect(original_transaction).to_not include_session_data("duplicate" => anything)
        expect(original_transaction).to include_environment(
          "REQUEST_METHOD" => "root",
          "REQUEST_PATH" => "/original",
          "PATH_INFO" => "/root2"
        )
        expect(original_transaction).to_not include_environment("HTTP_ACCEPT" => anything)
        expect(original_transaction).to include_custom_data(
          "root" => "custom",
          "original" => "custom",
          "root2" => "custom"
        )
        expect(original_transaction).to_not include_custom_data("duplicate" => anything)
        expect(original_transaction).to include_breadcrumb("breadcrumb", "root")
        expect(original_transaction).to include_breadcrumb("breadcrumb", "original")
        expect(original_transaction).to include_breadcrumb("breadcrumb", "root2")
        expect(original_transaction).to_not include_breadcrumb("breadcrumb", "duplicate")

        # Duplicate
        expect(duplicate_transaction).to include_tags(
          "root" => "tag",
          "duplicate" => "tag",
          "root2" => "tag"
        )
        expect(duplicate_transaction).to_not include_tags("original" => anything)
        expect(duplicate_transaction).to include_params(
          "root" => "param",
          "duplicate" => "param",
          "root2" => "param"
        )
        expect(duplicate_transaction).to_not include_params("original" => anything)
        expect(duplicate_transaction).to include_session_data(
          "root" => "session",
          "duplicate" => "session",
          "root2" => "session"
        )
        expect(duplicate_transaction).to_not include_session_data("original" => anything)
        expect(duplicate_transaction).to include_environment(
          "PATH_INFO" => "/root2",
          "HTTP_ACCEPT" => "duplicate",
          "REQUEST_METHOD" => "root"
        )
        expect(duplicate_transaction).to_not include_environment("REQUEST_PATH" => anything)
        expect(duplicate_transaction).to include_custom_data(
          "root" => "custom",
          "duplicate" => "custom",
          "root2" => "custom"
        )
        expect(duplicate_transaction).to_not include_custom_data("original" => anything)
        expect(duplicate_transaction).to include_breadcrumb("breadcrumb", "root")
        expect(duplicate_transaction).to include_breadcrumb("breadcrumb", "duplicate")
        expect(duplicate_transaction).to include_breadcrumb("breadcrumb", "root2")
        expect(duplicate_transaction).to_not include_breadcrumb("breadcrumb", "original")
      end

      it "overrides sample data from the original transaction in the duplicate transaction" do
        transaction.add_tags("changeme" => "tag")
        transaction.add_params("changeme" => "param")
        transaction.add_session_data("changeme" => "session")
        transaction.add_headers("REQUEST_METHOD" => "root")
        transaction.add_custom_data("changeme" => "custom")
        Appsignal.report_error(error)
        Appsignal.report_error(other_error) do |t|
          t.add_tags("changeme" => "duplicate_tag")
          t.add_params("changeme" => "duplicate_param")
          t.add_session_data("changeme" => "duplicate_session")
          t.add_headers("REQUEST_METHOD" => "duplicate")
          t.add_custom_data("changeme" => "duplicate_custom")
        end
        transaction.add_tags("changeme" => "changed_tag")
        transaction.add_params("changeme" => "changed_param")
        transaction.add_session_data("changeme" => "changed_session")
        transaction.add_headers("REQUEST_METHOD" => "changed")
        transaction.add_custom_data("changeme" => "changed_custom")
        transaction.complete

        original_transaction, duplicate_transaction = created_transactions
        # Original
        expect(original_transaction).to include_tags(
          "changeme" => "changed_tag"
        )
        expect(original_transaction).to include_params(
          "changeme" => "changed_param"
        )
        expect(original_transaction).to include_session_data(
          "changeme" => "changed_session"
        )
        expect(original_transaction).to include_environment(
          "REQUEST_METHOD" => "changed"
        )
        expect(original_transaction).to include_custom_data(
          "changeme" => "changed_custom"
        )

        # Duplicate
        expect(duplicate_transaction).to include_tags(
          "changeme" => "duplicate_tag"
        )
        expect(duplicate_transaction).to include_params(
          "changeme" => "duplicate_param"
        )
        expect(duplicate_transaction).to include_session_data(
          "changeme" => "duplicate_session"
        )
        expect(duplicate_transaction).to include_environment(
          "REQUEST_METHOD" => "duplicate"
        )
        expect(duplicate_transaction).to include_custom_data(
          "changeme" => "duplicate_custom"
        )
      end
    end

    describe "completed? after #complete" do
      it_in_both_modes do
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        transaction.complete

        expect(transaction.completed?).to be(true)
      end
    end

    describe "OpenTelemetry span emission" do
      it "emits no span until complete is called", :collector_mode do
        start_collector_agent
        create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        expect(span_exporter.finished_spans).to be_empty

        Appsignal::Transaction.complete_current!
        expect(span_exporter.finished_spans.size).to eq(1)
      end
    end
  end

  context "pausing" do
    let(:transaction) { new_transaction }

    describe "#pause!" do
      it "changes the pause flag to true" do
        expect do
          transaction.pause!
        end.to change(transaction, :paused?).from(false).to(true)
      end
    end

    describe "#resume!" do
      before { transaction.pause! }

      it "changes the pause flag to false" do
        expect do
          transaction.resume!
        end.to change(transaction, :paused?).from(true).to(false)
      end
    end

    describe "#paused?" do
      context "when not paused" do
        it "return false" do
          expect(transaction.paused?).to be_falsy
        end
      end

      context "when paused" do
        before { transaction.pause! }

        it "returns true" do
          expect(transaction.paused?).to be_truthy
        end
      end
    end
  end

  describe "#completed?" do
    let(:transaction) { new_transaction }

    context "when not completed" do
      it "returns false" do
        expect(transaction.completed?).to be_falsy
      end
    end

    context "when completed" do
      before { transaction.complete }

      it "returns true" do
        expect(transaction.completed?).to be_truthy
      end
    end
  end

  context "initialization" do
    let(:transaction) { new_transaction }

    it "loads the AppSignal extension" do
      expect(transaction.backend).to_not be_nil
    end

    context "when extension is not loaded", :extension_installation_failure do
      around do |example|
        Appsignal::Testing.without_testing { example.run }
      end

      it "does not error on missing extension method calls" do
        expect(transaction.backend).to be_kind_of(Appsignal::Transaction::ExtensionBackend)
        transaction.start_event
        transaction.finish_event(
          "name",
          "title",
          "body",
          Appsignal::EventFormatter::DEFAULT
        )
      end
    end

    it "sets the namespace to http_request" do
      expect(transaction.namespace).to eq "http_request"
    end
  end

  describe "#store" do
    let(:transaction) { new_transaction }

    it "returns an empty store when it's not already present" do
      expect(transaction.store("test")).to eql({})
    end

    it "stores changes to the store" do
      transaction_store = transaction.store("test")
      transaction_store["transaction"] = "value"

      expect(transaction.store("test")).to eql("transaction" => "value")
    end

    it "has a default value of a Hash for store values" do
      transaction.store("abc")["def"] = "123"

      expect(transaction.store("abc")).to eq("def" => "123")
      expect(transaction.store("xyz")).to eq({})
    end
  end

  describe "#add_params" do
    let(:transaction) { new_transaction }

    it "has a #set_params alias" do
      expect(transaction.method(:add_params)).to eq(transaction.method(:set_params))
    end

    describe "adding the params to the transaction" do
      def perform
        transaction.add_params("key" => "value")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
          .to eq("key" => "value")
      end
    end

    describe "merging the params on the transaction" do
      def perform
        transaction.add_params("abc" => "value")
        transaction.add_params("def" => "value")
        transaction.add_params { { "xyz" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params(
          "abc" => "value",
          "def" => "value",
          "xyz" => "value"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"])).to eq(
          "abc" => "value",
          "def" => "value",
          "xyz" => "value"
        )
      end
    end

    describe "adding the params to the transaction with a block" do
      def perform
        transaction.add_params { { "key" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
          .to eq("key" => "value")
      end
    end

    describe "adding the params block value when both an argument and block are given" do
      def perform
        transaction.add_params("argument" => "value") { { "block" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params("block" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
          .to eq("block" => "value")
      end
    end

    describe "when an error occurs storing the params" do
      def perform
        transaction.add_params { raise "uh oh" }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        logs = capture_logs { transaction._sample }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching params: RuntimeError: uh oh"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        logs = capture_logs { transaction.complete }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching params: RuntimeError: uh oh"
        )
        expect(root_span.attributes).to_not have_key("appsignal.request.payload")
      end
    end

    describe "when the given params value is nil" do
      def perform
        transaction.add_params("key" => "value")
        transaction.add_params(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
          .to eq("key" => "value")
      end
    end

    context "with AppSignal filtering" do
      let(:options) { { :filter_parameters => %w[foo] } }

      describe "sanitizing the params" do
        def perform
          transaction.add_params("foo" => "value", "baz" => "bat")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("foo" => "[FILTERED]", "baz" => "bat")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("foo" => "[FILTERED]", "baz" => "bat")
        end
      end
    end
  end

  describe "#add_params_if_nil" do
    let(:transaction) { new_transaction }

    it "has a #set_params_if_nil alias" do
      expect(transaction.method(:add_params_if_nil)).to eq(transaction.method(:set_params_if_nil))
    end

    context "when the params are not set" do
      describe "adding the params to the transaction" do
        def perform
          transaction.add_params_if_nil("key" => "value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("key" => "value")
        end
      end

      describe "adding the params to the transaction with a block" do
        def perform
          transaction.add_params_if_nil { { "key" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("key" => "value")
        end
      end

      describe "adding the params block value when both an argument and block are given" do
        def perform
          transaction.add_params_if_nil("argument" => "value") { { "block" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("block" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("block" => "value")
        end
      end

      describe "when the given value is nil" do
        def perform
          transaction.add_params("key" => "value")
          transaction.add_params_if_nil(nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("key" => "value")
        end
      end
    end

    context "when the params are set" do
      describe "not updating the params on the transaction" do
        def perform
          transaction.add_params("other" => "params")
          transaction.add_params_if_nil("key" => "value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("other" => "params")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("other" => "params")
        end
      end

      describe "not updating the params with a block on the transaction" do
        def perform
          transaction.add_params("other" => "params")
          transaction.add_params_if_nil { { "key" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_params("other" => "params")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
            .to eq("other" => "params")
        end
      end
    end

    context "when the params were set as an empty value" do
      describe "not setting params on the transaction" do
        def perform
          transaction.add_params("key1" => "value")
          transaction.set_empty_params!
          transaction.add_params_if_nil("key2" => "value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to_not include_params
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.request.payload")
        end
      end
    end
  end

  describe "#add_session_data" do
    let(:transaction) { new_transaction }

    it "has a #set_session_data alias" do
      expect(transaction.method(:add_session_data)).to eq(transaction.method(:set_session_data))
    end

    describe "adding the session data to the transaction" do
      def perform
        transaction.add_session_data("key" => "value")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
          .to eq("key" => "value")
      end
    end

    describe "merging the session data on the transaction" do
      def perform
        transaction.add_session_data("abc" => "value")
        transaction.add_session_data("def" => "value")
        transaction.add_session_data { { "xyz" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data(
          "abc" => "value",
          "def" => "value",
          "xyz" => "value"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"])).to eq(
          "abc" => "value",
          "def" => "value",
          "xyz" => "value"
        )
      end
    end

    describe "adding the session data to the transaction with a block" do
      def perform
        transaction.add_session_data { { "key" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
          .to eq("key" => "value")
      end
    end

    describe "adding the session data block when an argument and block are given" do
      def perform
        transaction.add_session_data("argument" => "value") { { "block" => "value" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data("block" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
          .to eq("block" => "value")
      end
    end

    describe "adding certain Ruby objects as Strings" do
      def perform
        transaction.add_session_data("time" => Time.utc(2024, 9, 12, 13, 14, 15))
        transaction.add_session_data("date" => Date.new(2024, 9, 11))
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data(
          "time" => "#<Time: 2024-09-12T13:14:15Z>",
          "date" => "#<Date: 2024-09-11>"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"])).to eq(
          "time" => "#<Time: 2024-09-12T13:14:15Z>",
          "date" => "#<Date: 2024-09-11>"
        )
      end
    end

    describe "when an error occurs storing the session data" do
      def perform
        transaction.add_session_data { raise "uh oh" }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        logs = capture_logs { transaction._sample }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching session data: RuntimeError: uh oh"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        logs = capture_logs { transaction.complete }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching session data: RuntimeError: uh oh"
        )
        expect(root_span.attributes).to_not have_key("appsignal.request.session_data")
      end
    end

    describe "when the given session data value is nil" do
      def perform
        transaction.add_session_data("key" => "value")
        transaction.add_session_data(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_session_data("key" => "value")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
          .to eq("key" => "value")
      end
    end

    context "with filter_session_data" do
      let(:options) { { :filter_session_data => ["filtered_key"] } }

      describe "filtering out session data" do
        def perform
          transaction.add_session_data("data" => "value1", "filtered_key" => "filtered_value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("data" => "value1")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          # Filtering redacts the value (mode-independent, applied before the
          # backend) rather than dropping the key.
          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("data" => "value1", "filtered_key" => "[FILTERED]")
        end
      end
    end
  end

  describe "#add_session_data_if_nil" do
    let(:transaction) { new_transaction }

    context "when the session data is not set" do
      describe "setting the session data on the transaction" do
        def perform
          transaction.add_session_data_if_nil("key" => "value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("key" => "value")
        end
      end

      describe "updating the session data on the transaction with a block" do
        def perform
          transaction.add_session_data_if_nil { { "key" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("key" => "value")
        end
      end

      describe "updating with the session data block when an argument and block are given" do
        def perform
          transaction.add_session_data_if_nil("argument" => "value") { { "block" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("block" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("block" => "value")
        end
      end

      describe "when the given value is nil" do
        def perform
          transaction.add_session_data("key" => "value")
          transaction.add_session_data_if_nil(nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("key" => "value")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("key" => "value")
        end
      end
    end

    context "when the session data are set" do
      describe "not updating the session data on the transaction" do
        def perform
          transaction.add_session_data("other" => "data")
          transaction.add_session_data_if_nil("key" => "value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("other" => "data")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("other" => "data")
        end
      end

      describe "not updating the session data with a block on the transaction" do
        def perform
          transaction.add_session_data("other" => "data")
          transaction.add_session_data_if_nil { { "key" => "value" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_session_data("other" => "data")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
            .to eq("other" => "data")
        end
      end
    end
  end

  describe "#add_headers" do
    let(:transaction) { new_transaction }

    it "has a #set_headers alias" do
      expect(transaction.method(:add_headers)).to eq(transaction.method(:set_headers))
    end

    describe "adding the headers to the transaction" do
      def perform
        # A true header (kept, normalized in collector mode) and a CGI var
        # (kept in agent mode, dropped in collector mode).
        transaction.add_headers("HTTP_ACCEPT" => "text/html", "PATH_INFO" => "/path")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_environment(
          "HTTP_ACCEPT" => "text/html",
          "PATH_INFO" => "/path"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        # True headers normalized to the OTel convention; non-header CGI vars
        # dropped.
        expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        expect(root_span.attributes).to_not have_key("http.request.header.path-info")
      end
    end

    describe "merging the headers on the transaction" do
      def perform
        transaction.add_headers("HTTP_ACCEPT" => "text/html")
        transaction.add_headers("HTTP_RANGE" => "bytes=0-")
        transaction.add_headers { { "HTTP_CACHE_CONTROL" => "no-cache" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_environment(
          "HTTP_ACCEPT" => "text/html",
          "HTTP_RANGE" => "bytes=0-",
          "HTTP_CACHE_CONTROL" => "no-cache"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        expect(root_span.attributes["http.request.header.range"]).to eq("bytes=0-")
        expect(root_span.attributes["http.request.header.cache-control"]).to eq("no-cache")
      end
    end

    describe "adding the headers to the transaction with a block" do
      def perform
        transaction.add_headers { { "HTTP_ACCEPT" => "text/html" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
      end
    end

    describe "adding the headers block value when both an argument and block are given" do
      def perform
        transaction.add_headers("HTTP_ACCEPT" => "arg") { { "HTTP_ACCEPT" => "block" } }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_environment("HTTP_ACCEPT" => "block")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes["http.request.header.accept"]).to eq("block")
      end
    end

    describe "when an error occurs storing the headers" do
      def perform
        transaction.add_headers { raise "uh oh" }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        logs = capture_logs { transaction._sample }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching headers: RuntimeError: uh oh"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        logs = capture_logs { transaction.complete }
        expect(logs).to contains_log(
          :error,
          "Exception while fetching headers: RuntimeError: uh oh"
        )
      end
    end

    describe "when the given headers value is nil" do
      def perform
        transaction.add_headers("HTTP_ACCEPT" => "text/html")
        transaction.add_headers(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
      end
    end

    context "with request_headers options" do
      let(:options) { { :request_headers => ["HTTP_ACCEPT"] } }

      describe "filtering out headers not in the allowlist" do
        def perform
          transaction.add_headers("HTTP_ACCEPT" => "text/html", "HTTP_RANGE" => "bytes=0-")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
          expect(transaction).to_not include_environment("HTTP_RANGE" => "bytes=0-")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
          expect(root_span.attributes).to_not have_key("http.request.header.range")
        end
      end
    end
  end

  describe "#add_headers_if_nil" do
    let(:transaction) { new_transaction }

    it "has a #set_headers_if_nil alias" do
      expect(transaction.method(:add_headers_if_nil)).to eq(transaction.method(:set_headers_if_nil))
    end

    context "when the headers are not set" do
      describe "adding the headers to the transaction" do
        def perform
          transaction.add_headers_if_nil("HTTP_ACCEPT" => "text/html")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        end
      end

      describe "adding the headers to the transaction with a block" do
        def perform
          transaction.add_headers_if_nil { { "HTTP_ACCEPT" => "text/html" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        end
      end

      describe "adding the headers block value when an argument and block are given" do
        def perform
          transaction.add_headers_if_nil("HTTP_ACCEPT" => "arg") { { "HTTP_ACCEPT" => "block" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "block")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("block")
        end
      end

      describe "when the given value is nil" do
        def perform
          transaction.add_headers("HTTP_ACCEPT" => "text/html")
          transaction.add_headers_if_nil(nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "text/html")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("text/html")
        end
      end
    end

    context "when the headers are set" do
      describe "not updating the headers on the transaction" do
        def perform
          transaction.add_headers("HTTP_ACCEPT" => "first")
          transaction.add_headers_if_nil("HTTP_ACCEPT" => "other")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "first")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("first")
        end
      end

      describe "not updating the headers with a block on the transaction" do
        def perform
          transaction.add_headers("HTTP_ACCEPT" => "first")
          transaction.add_headers_if_nil { { "HTTP_ACCEPT" => "other" } }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_environment("HTTP_ACCEPT" => "first")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["http.request.header.accept"]).to eq("first")
        end
      end
    end
  end

  describe "#add_tags" do
    let(:transaction) { new_transaction }
    let(:long_string) { "a" * 10_001 }

    describe "storing tags on the transaction" do
      def perform
        transaction.add_tags(
          :valid_key => "valid_value",
          "valid_string_key" => "valid_value",
          :both_symbols => :valid_value,
          :integer_value => 1,
          :hash_value => { "invalid" => "hash" },
          :array_value => %w[invalid array],
          :object => Object.new,
          :too_long_value => long_string,
          long_string => "too_long_key",
          :true_tag => true,
          :false_tag => false
        )
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        # The extension truncates over-long tag values to 10,000 chars + "...".
        expect(transaction).to include_tags(
          "valid_key" => "valid_value",
          "valid_string_key" => "valid_value",
          "both_symbols" => "valid_value",
          "integer_value" => 1,
          "too_long_value" => "#{"a" * 10_000}...",
          long_string => "too_long_key",
          "true_tag" => true,
          "false_tag" => false
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        attributes = root_span.attributes
        # Each tag is its own `appsignal.tag.<key>` attribute. Symbols are
        # coerced to strings; over-long values are sent whole (not truncated
        # like the extension does) -- the collector/server apply their limits.
        expect(attributes["appsignal.tag.valid_key"]).to eq("valid_value")
        expect(attributes["appsignal.tag.valid_string_key"]).to eq("valid_value")
        expect(attributes["appsignal.tag.both_symbols"]).to eq("valid_value")
        expect(attributes["appsignal.tag.integer_value"]).to eq(1)
        expect(attributes["appsignal.tag.true_tag"]).to eq(true)
        expect(attributes["appsignal.tag.false_tag"]).to eq(false)
        expect(attributes["appsignal.tag.too_long_value"]).to eq(long_string)
        expect(attributes["appsignal.tag.#{long_string}"]).to eq("too_long_key")
        # Non-primitive tag values are dropped by `sanitized_tags` in both modes.
        expect(attributes).to_not have_key("appsignal.tag.hash_value")
        expect(attributes).to_not have_key("appsignal.tag.array_value")
        expect(attributes).to_not have_key("appsignal.tag.object")
      end
    end

    describe "merging the tags when called multiple times" do
      def perform
        transaction.add_tags(:key1 => "value1")
        transaction.add_tags(:key2 => "value2")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_tags(
          "key1" => "value1",
          "key2" => "value2"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes["appsignal.tag.key1"]).to eq("value1")
        expect(root_span.attributes["appsignal.tag.key2"]).to eq("value2")
      end
    end

    context "with config default_tags" do
      let(:options) do
        { :default_tags => { "config_tag" => "config_value", "another_tag" => 123 } }
      end

      describe "including default_tags from config" do
        def perform
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_tags(
            "config_tag" => "config_value",
            "another_tag" => 123
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["appsignal.tag.config_tag"]).to eq("config_value")
          expect(root_span.attributes["appsignal.tag.another_tag"]).to eq(123)
        end
      end

      describe "transaction tags override default_tags" do
        def perform
          transaction.add_tags("config_tag" => "transaction_value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_tags(
            "config_tag" => "transaction_value",
            "another_tag" => 123
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["appsignal.tag.config_tag"]).to eq("transaction_value")
          expect(root_span.attributes["appsignal.tag.another_tag"]).to eq(123)
        end
      end

      describe "merging default_tags with transaction tags" do
        def perform
          transaction.add_tags("transaction_tag" => "transaction_value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform
          transaction._sample

          expect(transaction).to include_tags(
            "config_tag" => "config_value",
            "another_tag" => 123,
            "transaction_tag" => "transaction_value"
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes["appsignal.tag.config_tag"]).to eq("config_value")
          expect(root_span.attributes["appsignal.tag.another_tag"]).to eq(123)
          expect(root_span.attributes["appsignal.tag.transaction_tag"]).to eq("transaction_value")
        end
      end
    end
  end

  describe "#add_custom_data" do
    let(:transaction) { new_transaction }

    it "has a #add_custom_data alias" do
      expect(transaction.method(:add_custom_data)).to eq(transaction.method(:set_custom_data))
    end

    describe "adding a custom Hash data to the transaction" do
      def perform
        transaction.add_custom_data(
          :user => {
            :id => 123,
            :locale => "abc"
          },
          :organization => {
            :slug => "appsignal",
            :plan => "enterprise"
          }
        )
      end

      let(:expected) do
        {
          "user" => {
            "id" => 123,
            "locale" => "abc"
          },
          "organization" => {
            "slug" => "appsignal",
            "plan" => "enterprise"
          }
        }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_custom_data(expected)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.custom_data"])).to eq(expected)
      end
    end

    describe "adding a custom Array data to the transaction" do
      def perform
        transaction.add_custom_data([
          [123, "abc"],
          ["appsignal", "enterprise"]
        ])
      end

      let(:expected) { [[123, "abc"], ["appsignal", "enterprise"]] }

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_custom_data(expected)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.custom_data"])).to eq(expected)
      end
    end

    describe "storing non Hash or Array custom data" do
      def perform
        transaction.add_custom_data("abc")
        transaction.add_custom_data(123)
        transaction.add_custom_data(Object.new)
      end

      def expect_unsupported_type_logs(logs)
        expect(logs).to contains_log(
          :error,
          %(Sample data 'custom_data': Unsupported data type 'String' received: "abc")
        )
        expect(logs).to contains_log(
          :error,
          %(Sample data 'custom_data': Unsupported data type 'Integer' received: 123)
        )
        expect(logs).to contains_log(
          :error,
          %(Sample data 'custom_data': Unsupported data type 'Object' received: #<Object:)
        )
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        logs = capture_logs do
          perform
          transaction._sample
        end

        expect(transaction).to_not include_custom_data
        expect_unsupported_type_logs(logs)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        logs = capture_logs do
          perform
          transaction.complete
        end

        expect(root_span.attributes).to_not have_key("appsignal.custom_data")
        expect_unsupported_type_logs(logs)
      end
    end

    describe "merging the custom data if called multiple times" do
      def perform
        transaction.add_custom_data("abc" => "value")
        transaction.add_custom_data("def" => "value")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_custom_data(
          "abc" => "value",
          "def" => "value"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.custom_data"])).to eq(
          "abc" => "value",
          "def" => "value"
        )
      end
    end
  end

  describe "#add_breadcrumb" do
    let(:transaction) { new_transaction }

    # The OpenTelemetry `appsignal.breadcrumb` events recorded on the root span.
    def breadcrumb_events
      root_span.events.to_a.select { |event| event.name == "appsignal.breadcrumb" }
    end

    context "when over the limit" do
      def perform
        22.times do |i|
          transaction.add_breadcrumb(
            "network",
            "GET http://localhost",
            "User made external network request",
            { :code => i + 1 },
            Time.parse("10-10-2010 10:00:00 UTC")
          )
        end
      end

      it "stores last <LIMIT> breadcrumbs on the transaction in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction.to_h["sample_data"]["breadcrumbs"].length).to eql(20)
        expect(transaction.to_h["sample_data"]["breadcrumbs"][0]).to eq(
          "action" => "GET http://localhost",
          "category" => "network",
          "message" => "User made external network request",
          "metadata" => { "code" => 3 },
          "time" => 1286704800 # rubocop:disable Style/NumericLiterals
        )
        expect(transaction.to_h["sample_data"]["breadcrumbs"][19]).to eq(
          "action" => "GET http://localhost",
          "category" => "network",
          "message" => "User made external network request",
          "metadata" => { "code" => 22 },
          "time" => 1286704800 # rubocop:disable Style/NumericLiterals
        )
      end

      it "emits the last <LIMIT> breadcrumb events in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        events = breadcrumb_events
        expect(events.length).to eq(20)
        expect(events.first.attributes).to include(
          "category" => "network",
          "action" => "GET http://localhost",
          "message" => "User made external network request"
        )
        expect(JSON.parse(events.first.attributes["metadata"])).to eq("code" => 3)
        expect(JSON.parse(events.last.attributes["metadata"])).to eq("code" => 22)
      end
    end

    context "with defaults" do
      def perform
        transaction.add_breadcrumb("user_action", "clicked HOME")
      end

      it "stores breadcrumb with defaults on transaction in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        timeframe_start = Time.now.utc.to_i
        perform
        transaction._sample
        timeframe_end = Time.now.utc.to_i

        expect(transaction).to include_breadcrumb(
          "clicked HOME",
          "user_action",
          "",
          {},
          be_between(timeframe_start, timeframe_end)
        )
      end

      it "emits a breadcrumb event with defaults on the span in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        events = breadcrumb_events
        expect(events.length).to eq(1)
        expect(events.first.attributes).to include(
          "category" => "user_action",
          "action" => "clicked HOME",
          "message" => "",
          "metadata" => "{}"
        )
      end
    end

    context "with metadata argument that's not a Hash" do
      def perform
        transaction.add_breadcrumb("category", "action", "message", "invalid metadata")
      end

      it "does not add the breadcrumb and logs an error in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        logs = capture_logs { perform }
        transaction._sample

        expect(transaction).to_not include_breadcrumbs
        expect(logs).to contains_log(
          :error,
          "add_breadcrumb: Cannot add breadcrumb. The given metadata argument is not a Hash."
        )
      end

      it "does not emit a breadcrumb event and logs an error in collector mode", :collector_mode do
        start_collector_agent
        logs = capture_logs { perform }
        transaction.complete

        expect(breadcrumb_events).to be_empty
        expect(logs).to contains_log(
          :error,
          "add_breadcrumb: Cannot add breadcrumb. The given metadata argument is not a Hash."
        )
      end
    end
  end

  describe "#set_action" do
    let(:transaction) { new_transaction }
    let(:action_name) { "PagesController#show" }

    context "when the action is set" do
      def perform
        transaction.set_action(action_name)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(transaction.action).to eq(action_name)
        transaction.complete
        expect(root_span.name).to eq(action_name)
        expect(root_span.attributes["appsignal.action_name"]).to eq(action_name)
      end
    end

    context "when the action is nil" do
      def perform
        transaction.set_action(action_name)
        transaction.set_action(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(transaction.action).to eq(action_name)
        transaction.complete
        expect(root_span.name).to eq(action_name)
        expect(root_span.attributes["appsignal.action_name"]).to eq(action_name)
      end
    end
  end

  describe "#set_action_if_nil" do
    let(:transaction) { new_transaction }

    context "when the action is not set" do
      let(:action_name) { "PagesController#show" }

      def perform
        transaction.set_action_if_nil(action_name)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        expect(transaction.action).to eq(nil)
        expect(transaction).to_not have_action

        perform

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect(transaction.action).to eq(nil)

        perform

        expect(transaction.action).to eq(action_name)
        transaction.complete
        expect(root_span.name).to eq(action_name)
        expect(root_span.attributes["appsignal.action_name"]).to eq(action_name)
      end

      context "when the given action is nil" do
        let(:action_name) { "something" }

        def perform
          transaction.set_action(action_name)
          transaction.set_action_if_nil(nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(transaction.action).to eq(action_name)
          expect(transaction).to have_action(action_name)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(transaction.action).to eq(action_name)
          transaction.complete
          expect(root_span.attributes["appsignal.action_name"]).to eq(action_name)
        end
      end
    end

    context "when the action is set" do
      let(:action_name) { "something" }

      def perform
        transaction.set_action(action_name)
        transaction.set_action_if_nil("something else")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(transaction.action).to eq(action_name)
        transaction.complete
        expect(root_span.name).to eq(action_name)
        expect(root_span.attributes["appsignal.action_name"]).to eq(action_name)
      end
    end
  end

  describe "#set_namespace" do
    let(:transaction) { new_transaction }
    let(:namespace) { "custom" }

    context "when the namespace is not nil" do
      def perform
        transaction.set_namespace(namespace)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction.namespace).to eq namespace
        expect(transaction).to have_namespace(namespace)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(transaction.namespace).to eq namespace
        transaction.complete
        expect(root_span.attributes["appsignal.namespace"]).to eq(namespace)
      end
    end

    context "when the namespace is nil" do
      def perform
        transaction.set_namespace(namespace)
        transaction.set_namespace(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction.namespace).to eq(namespace)
        expect(transaction).to have_namespace(namespace)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(transaction.namespace).to eq(namespace)
        transaction.complete
        expect(root_span.attributes["appsignal.namespace"]).to eq(namespace)
      end
    end

    context "when set_namespace is never called", :collector_mode do
      it "carries the namespace from creation" do
        start_collector_agent
        transaction = http_request_transaction
        transaction.complete

        expect(root_span.attributes["appsignal.namespace"])
          .to eq(Appsignal::Transaction::HTTP_REQUEST)
      end
    end
  end

  describe "#set_queue_start" do
    let(:transaction) { new_transaction }

    describe "setting the queue start" do
      def perform
        transaction.set_queue_start(10)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to have_queue_start(10)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        # Intentional no-op in collector mode: nothing consumes a queue start in
        # the OTel pipeline, so no attribute is emitted.
        expect(root_span.attributes.keys.grep(/queue/i)).to be_empty
      end
    end

    describe "when the value is nil" do
      def perform
        transaction.set_queue_start(nil)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to_not have_queue_start
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(root_span.attributes.keys.grep(/queue/i)).to be_empty
      end
    end

    it_in_both_modes "does not raise an error when the queue start is too big" do
      expect(transaction.backend).to receive(:set_queue_start).and_raise(RangeError)

      expect(Appsignal.internal_logger).to receive(:warn).with("Queue start value 10 is too big")

      transaction.set_queue_start(10)
      # Complete so the collector-mode example detaches its OTel context rather
      # than leaking it into later examples.
      transaction.complete
    end
  end

  describe "#set_metadata" do
    let(:transaction) { new_transaction }

    describe "updating the metadata on the transaction" do
      def perform
        transaction.set_metadata("request_method", "GET")
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to include_metadata("request_method" => "GET")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        # Metadata has no dedicated OTel attribute; it is emitted as a tag.
        expect(root_span.attributes["appsignal.tag.request_method"]).to eq("GET")
      end
    end

    context "when filter_metadata includes metadata key" do
      let(:options) { { :filter_metadata => ["filter_key"] } }

      describe "not setting the filtered metadata" do
        def perform
          transaction.set_metadata(:filter_key, "filtered value")
          transaction.set_metadata("filter_key", "filtered value")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(transaction).to_not include_metadata("filter_key" => anything)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.tag.filter_key")
        end
      end
    end

    context "when the key is nil" do
      describe "not updating the metadata" do
        def perform
          transaction.set_metadata(nil, "GET")
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(transaction).to_not include_metadata
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes.keys.grep(/appsignal\.tag\./)).to be_empty
        end
      end
    end

    context "when the value is nil" do
      describe "not updating the metadata" do
        def perform
          transaction.set_metadata("request_method", nil)
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(transaction).to_not include_metadata
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          expect(root_span.attributes.keys.grep(/appsignal\.tag\./)).to be_empty
        end
      end
    end
  end

  describe "when metadata and a tag share a key (collector mode)" do
    # In collector mode both metadata and tags are emitted as `appsignal.tag.*`
    # span attributes, so a shared key collides on one attribute. `set_metadata`
    # writes the attribute immediately, while tags are flushed at `complete` (via
    # the sample data), so the tag is written last and wins -- regardless of the
    # order the two were set in. (In agent mode they are stored separately and
    # never collide, so this is collector-specific.)
    it "the tag value wins", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      transaction.add_tags("shared" => "from_tag")
      transaction.set_metadata("shared", "from_metadata")
      transaction.complete

      expect(root_span.attributes["appsignal.tag.shared"]).to eq("from_tag")
    end

    it "the tag value wins even when the tag is added after the metadata", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      transaction.set_metadata("shared", "from_metadata")
      transaction.add_tags("shared" => "from_tag")
      transaction.complete

      expect(root_span.attributes["appsignal.tag.shared"]).to eq("from_tag")
    end
  end

  describe "storing sample data" do
    let(:transaction) { new_transaction }

    describe "storing sample data on the transaction" do
      def perform
        transaction.set_params(
          "string_param" => "string_value",
          :symbol_param => "symbol_value",
          "integer" => 123,
          "float" => 123.45,
          "array" => ["abc", 456, { "option" => true }],
          "hash" => { "hash_key" => "hash_value" }
        )
      end

      let(:expected) do
        {
          "string_param" => "string_value",
          "symbol_param" => "symbol_value",
          "integer" => 123,
          "float" => 123.45,
          "array" => ["abc", 456, { "option" => true }],
          "hash" => { "hash_key" => "hash_value" }
        }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        transaction._sample

        expect(transaction).to include_params(expected)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"])).to eq(expected)
      end
    end

    describe "storing non-Array and non-Hash data" do
      def perform
        transaction.set_params("some string")
        transaction.set_params(123)
        transaction.set_params(Class.new)
        set = Set.new
        set.add("abc")
        transaction.set_params(set)
      end

      def expect_unsupported_type_logs(logs)
        expect(logs).to contains_log(
          :error,
          %(Sample data 'params': Unsupported data type 'String' received: "some string")
        )
        expect(logs).to contains_log(
          :error,
          %(Sample data 'params': Unsupported data type 'Integer' received: 123)
        )
        expect(logs).to contains_log(
          :error,
          %(Sample data 'params': Unsupported data type 'Class' received: #<Class)
        )
        expect(logs).to contains_log(
          :error,
          /Sample data 'params': Unsupported data type 'Set' received: (#<Set: {|Set\[)"abc"(}>|\])/
        )
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        logs = capture_logs do
          perform
          transaction._sample
        end

        expect(transaction).to_not include_params
        expect_unsupported_type_logs(logs)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        logs = capture_logs do
          perform
          transaction.complete
        end

        expect(root_span.attributes).to_not have_key("appsignal.request.payload")
        expect_unsupported_type_logs(logs)
      end
    end

    describe "storing data that can't be serialized" do
      let(:unserializable) do
        Class.new do
          def initialize
            @calls = 0
          end

          def to_s
            raise "foo" if @calls > 0 # Cause a deliberate error

            @calls += 1
          end
        end
      end

      def perform
        transaction.set_params(unserializable.new => 1)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        logs = capture_logs { transaction._sample }

        expect(transaction).to_not include_params
        expect(logs).to contains_log :error,
          "Error generating data (RuntimeError: foo) for"
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        logs = capture_logs { transaction.complete }

        expect(root_span.attributes).to_not have_key("appsignal.request.payload")
        expect(logs).to contains_log :error,
          "Error generating data (RuntimeError: foo) for"
      end
    end
  end

  describe "#set_sample_data" do
    let(:transaction) { new_transaction }

    describe "updating the sample data on the transaction" do
      def perform
        silence do
          transaction.send(
            :set_sample_data,
            "params",
            :controller => "blog_posts",
            :action     => "show",
            :id         => "1"
          )
        end
      end

      let(:expected) do
        { "action" => "show", "controller" => "blog_posts", "id" => "1" }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to include_params(expected)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        expect(JSON.parse(root_span.attributes["appsignal.request.payload"])).to eq(expected)
      end
    end

    context "when the data is no Array or Hash" do
      describe "not updating the sample data" do
        def perform
          silence { transaction.send(:set_sample_data, "params", "string") }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          logs = capture_logs { perform }

          expect(transaction.to_h["sample_data"]).to eq({})
          expect(logs).to contains_log :error,
            %(Invalid sample data for 'params'. Value is not an Array or Hash: '"string"')
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          logs = capture_logs { perform }
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.request.payload")
          expect(logs).to contains_log :error,
            %(Invalid sample data for 'params'. Value is not an Array or Hash: '"string"')
        end
      end
    end

    context "when the data cannot be converted" do
      # The direct call skips sanitization, so the raw object reaches the
      # backend serializer (`Data.generate` in agent mode, `JSON.generate` in
      # collector mode); both call `to_s` and rescue the resulting error.
      describe "not updating the sample data" do
        let(:unserializable) do
          Class.new do
            def to_s
              raise "foo" # Cause a deliberate error
            end
          end
        end

        def perform
          silence { transaction.send(:set_sample_data, "params", unserializable.new => 1) }
        end

        it "in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          logs = capture_logs { perform }

          expect(transaction).to_not include_params
          expect(logs).to contains_log :error,
            "Error generating data (RuntimeError: foo) for"
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          logs = capture_logs { perform }
          transaction.complete

          expect(root_span.attributes).to_not have_key("appsignal.request.payload")
          expect(logs).to contains_log :error,
            "Error generating data (RuntimeError: foo) for"
        end
      end
    end
  end

  describe "#add_error" do
    let(:transaction) { create_transaction }

    let(:error) do
      ExampleStandardError.new("test message").tap do |e|
        e.set_backtrace(["line 1"])
      end
    end

    context "when error argument is not an error" do
      let(:error) { Object.new }

      it "does not add the error" do
        logs = capture_logs { transaction.add_error(error) }

        expect(transaction).to_not have_error
        expect(logs).to contains_log(
          :error,
          "Appsignal::Transaction#add_error: Cannot add error. " \
            "The given value is not an exception: #{error.inspect}"
        )
      end
    end

    context "when AppSignal is not active" do
      it "does not add the error" do
        allow(Appsignal).to receive(:active?).and_return(false)

        transaction.add_error(error)

        expect(transaction).to_not have_error
      end
    end

    context "when the error is already reported" do
      it "does not add the error" do
        # Report it on another transaction first
        transaction1 = new_transaction
        transaction1.add_error(error)
        expect(transaction1).to have_error

        transaction2 = new_transaction
        transaction2.add_error(error)
        expect(transaction2).to_not have_error
      end
    end

    context "when the error cause is already reported" do
      it "does not add the error" do
        error =
          begin
            begin
              raise ExampleStandardError, "error cause"
            rescue
              raise ExampleException, "error wrapper"
            end
          rescue ExampleException => e
            e
          end

        # Report the wrapper on another transaction first
        transaction1 = new_transaction
        transaction1.add_error(error)
        expect(transaction1).to have_error

        transaction2 = new_transaction
        transaction2.add_error(error.cause)
        expect(transaction).to_not have_error
      end
    end

    context "when a block is given" do
      it "stores the block in the error blocks" do
        block = proc { "block" }

        transaction.add_error(error, &block)

        expect(transaction.error_blocks).to eq({
          error => [block]
        })
      end
    end

    context "when no error is set in the transaction" do
      it "sets the error on the transaction" do
        transaction.add_error(error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "test message",
          ["line 1"]
        )
      end

      it "does store the error in the errors" do
        transaction.add_error(error)

        expect(transaction.error_blocks).to eq({ error => [] })
      end
    end

    describe "recording the error on the span" do
      def perform
        transaction.add_error(error)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to have_error(
          "ExampleStandardError",
          "test message",
          ["line 1"]
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        event = root_span.events.find { |e| e.name == "exception" }
        expect(event).not_to be_nil
        expect(event.attributes["exception.type"]).to eq("ExampleStandardError")
        expect(event.attributes["exception.message"]).to eq("test message")
        expect(event.attributes["exception.stacktrace"]).to eq("line 1")
        expect(event.attributes).not_to have_key("appsignal.error_causes")
        expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
      end
    end

    describe "recording an error that has causes" do
      let(:error) do
        cause = ExampleStandardError.new("cause message").tap do |e|
          e.set_backtrace(["/path/cause.rb:1:in `cause_method'"])
        end
        ExampleException.new("wrapper message").tap do |e|
          e.set_backtrace(["/path/wrapper.rb:2:in `wrapper_method'"])
          allow(e).to receive(:cause).and_return(cause)
        end
      end

      def perform
        # Hide Rails so the backtrace isn't run through its cleaner, keeping the
        # asserted lines deterministic (mirrors the error-causes sample-data spec).
        hide_const("Rails")
        transaction.add_error(error)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to have_error("ExampleException", "wrapper message")
        expect(transaction).to include_error_causes(
          [hash_including("name" => "ExampleStandardError", "message" => "cause message")]
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        event = root_span.events.find { |e| e.name == "exception" }
        expect(event.attributes["exception.type"]).to eq("ExampleException")
        # `appsignal.error_causes` matches the processor's ErrorSubCause shape:
        # name / message / lines (full cleaned backtrace per cause).
        expect(JSON.parse(event.attributes["appsignal.error_causes"])).to eq(
          [
            {
              "name" => "ExampleStandardError",
              "message" => "cause message",
              "lines" => ["/path/cause.rb:1:in `cause_method'"]
            }
          ]
        )
      end
    end

    describe "recording multiple errors" do
      let(:other_error) do
        ExampleStandardError.new("other message").tap { |e| e.set_backtrace(["line 2"]) }
      end

      def perform
        transaction.add_error(error)
        transaction.add_error(other_error)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform
        # The extension holds one error per transaction, so the extra error is
        # reported as a duplicate transaction.
        expect { transaction.complete }.to change { created_transactions.count }.by(1)

        original_transaction, duplicate_transaction = created_transactions
        expect(original_transaction).to have_error(
          "ExampleStandardError", "test message", ["line 1"]
        )
        expect(duplicate_transaction).to have_error(
          "ExampleStandardError", "other message", ["line 2"]
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        # One trace: a single root span carrying one exception event per error.
        root_spans = span_exporter.finished_spans.select do |span|
          [:server, :consumer].include?(span.kind)
        end
        expect(root_spans.size).to eq(1)

        events = root_spans.first.events.select { |e| e.name == "exception" }
        expect(events.map { |e| e.attributes["exception.type"] })
          .to contain_exactly("ExampleStandardError", "ExampleStandardError")
        expect(events.map { |e| e.attributes["exception.message"] })
          .to contain_exactly("test message", "other message")
      end
    end

    # Collector-mode-specific behavior (no agent-mode analog): the error is
    # recorded on the span that is current when `add_error` is called.
    it "records the error on the current event span", :collector_mode do
      start_collector_agent
      transaction.start_event
      transaction.add_error(error)
      transaction.finish_event("query", "title", "body", Appsignal::EventFormatter::DEFAULT)
      transaction.complete

      event_span = event_spans.find { |span| span.attributes["appsignal.category"] == "query" }
      expect(event_span.events.map(&:name)).to include("exception")
      expect(Array(root_span.events).map(&:name)).not_to include("exception")
    end

    # Collector-mode-specific: errors collapse onto one trace, so error blocks
    # merge onto the transaction in order -- the last-added error wins on a
    # shared key.
    it "applies error blocks in order, last-added error wins", :collector_mode do
      start_collector_agent
      second_error = ExampleStandardError.new("second message")
      transaction.add_error(error) { |t| t.set_action("FirstAction") }
      transaction.add_error(second_error) { |t| t.set_action("SecondAction") }
      transaction.complete

      expect(root_span.name).to eq("SecondAction")
      expect(root_span.attributes["appsignal.action_name"]).to eq("SecondAction")
    end

    context "when an error is already set in the transaction" do
      let(:other_error) do
        ExampleStandardError.new("other test message").tap do |e|
          e.set_backtrace(["line 2"])
        end
      end

      before { transaction.set_error(other_error) }

      it "stores an error in the errors" do
        transaction.add_error(error)

        expect(transaction.error_blocks).to eq({
          other_error => [],
          error => []
        })
      end

      it "does not set the error on the extension" do
        transaction.add_error(error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "other test message",
          ["line 2"]
        )
      end
    end

    context "when the error has already been added" do
      before { transaction.add_error(error) }

      it "does not add the error to the errors" do
        expect(transaction.error_blocks).to eq({ error => [] })

        transaction.add_error(error)

        expect(transaction.error_blocks).to eq({ error => [] })
      end

      context "when a block is given" do
        it "adds the block to the error blocks" do
          block = proc { "block" }

          transaction.add_error(error, &block)

          expect(transaction.error_blocks).to eq({ error => [block] })
        end
      end
    end

    context "when the errors is at the limit" do
      let(:seen_error) { ExampleStandardError.new("error 0") }

      before do
        transaction.add_error(seen_error)

        9.times do |i|
          transaction.add_error(ExampleStandardError.new("error #{i}"))
        end
      end

      it "does not add a new error to the errors" do
        expect(transaction).to have_error("ExampleStandardError", "error 0", [])
        expect(transaction.error_blocks.length).to eq(10)
        expected_error_blocks = transaction.error_blocks.dup

        transaction.add_error(error)

        expect(transaction).to have_error("ExampleStandardError", "error 0", [])
        expect(transaction.error_blocks).to eq(expected_error_blocks)
      end

      it "logs a debug message" do
        logs = capture_logs { transaction.add_error(error) }

        expect(logs).to contains_log(
          :warn,
          "Appsignal::Transaction#add_error: Transaction has more than 10 distinct errors. " \
            "Only the first 10 distinct errors will be reported."
        )
      end

      context "when the error has already been added" do
        it "does not add the error to the errors" do
          expect(transaction.error_blocks.length).to eq(10)

          transaction.add_error(seen_error)

          expect(transaction.error_blocks.length).to eq(10)
        end

        it "does add the block to the error blocks" do
          block = proc { "block" }

          transaction.add_error(seen_error, &block)

          expect(transaction.error_blocks[seen_error]).to eq([block])
        end

        it "does not log a debug message" do
          logs = capture_logs { transaction.add_error(seen_error) }

          expect(logs).to_not contains_log(
            :warn,
            "Appsignal::Transaction#add_error: Transaction has more than 10 distinct errors. " \
              "Only the first 10 distinct errors will be reported."
          )
        end
      end
    end

    context "with a PG::UniqueViolation" do
      let(:error) do
        PG::UniqueViolation.new(
          "ERROR: duplicate key value violates unique constraint " \
            "\"index_users_on_email\" DETAIL: Key (email)=(test@test.com) already exists."
        )
      end
      let(:sanitized_message) do
        "ERROR: duplicate key value violates unique constraint " \
          "\"index_users_on_email\" DETAIL: Key (email)=(?) already exists."
      end
      before { stub_const("PG::UniqueViolation", Class.new(StandardError)) }

      def perform
        transaction.add_error(error)
      end

      it "returns a sanizited error message in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to have_error("PG::UniqueViolation", sanitized_message)
      end

      it "records a sanitized error message in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        event = exception_event
        expect(event.attributes["exception.type"]).to eq("PG::UniqueViolation")
        expect(event.attributes["exception.message"]).to eq(sanitized_message)
      end
    end

    context "with a ActiveRecord::RecordNotUnique" do
      let(:error) do
        ActiveRecord::RecordNotUnique.new(
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
            "\"example_constraint\"\nDETAIL: Key (email)=(foo@example.com) already exists."
        )
      end
      let(:sanitized_message) do
        "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
          "\"example_constraint\"\nDETAIL: Key (email)=(?) already exists."
      end
      before { stub_const("ActiveRecord::RecordNotUnique", Class.new(StandardError)) }

      def perform
        transaction.add_error(error)
      end

      it "returns a sanizited error message in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(transaction).to have_error("ActiveRecord::RecordNotUnique", sanitized_message)
      end

      it "records a sanitized error message in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        event = exception_event
        expect(event.attributes["exception.type"]).to eq("ActiveRecord::RecordNotUnique")
        expect(event.attributes["exception.message"]).to eq(sanitized_message)
      end
    end

    context "with Rails module but without backtrace_cleaner method" do
      def perform
        stub_const("Rails", Module.new)
        error = ExampleStandardError.new("error message")
        error.set_backtrace(["line 1", "line 2"])
        transaction.add_error(error)
      end

      it "returns the backtrace uncleaned in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        perform

        expect(last_transaction).to have_error(
          "ExampleStandardError",
          "error message",
          ["line 1", "line 2"]
        )
      end

      it "records the backtrace uncleaned in collector mode", :collector_mode do
        start_collector_agent
        perform
        transaction.complete

        event = exception_event
        expect(event.attributes["exception.stacktrace"]).to eq("line 1\nline 2")
      end
    end

    if rails_present?
      context "with Rails" do
        let(:test_filter) do
          lambda do |line|
            if Appsignal::Testing.store[:enable_rails_backtrace_line_filter]
              line.tr("2", "?")
            else
              line
            end
          end
        end
        before do
          Appsignal::Testing.store[:enable_rails_backtrace_line_filter] = true
          ::Rails.backtrace_cleaner.add_filter(&test_filter)
        end

        def perform
          error = ExampleStandardError.new("error message")
          error.set_backtrace(["line 1", "line 2"])
          transaction.add_error(error)
        end

        it "cleans the backtrace with the Rails backtrace cleaner in agent mode", :agent_mode do
          start_agent(**start_agent_args)
          perform

          expect(last_transaction).to have_error(
            "ExampleStandardError",
            "error message",
            ["line 1", "line ?"]
          )
        end

        it "cleans the backtrace with the Rails backtrace cleaner in collector mode",
          :collector_mode do
          start_collector_agent
          perform
          transaction.complete

          event = exception_event
          expect(event.attributes["exception.stacktrace"]).to eq("line 1\nline ?")
        end
      end
    end

    # The completed root span's sole `exception` span-event, for asserting
    # collector-mode error attributes.
    def exception_event
      root_span.events.find { |event| event.name == "exception" }
    end
  end

  describe "#_set_error" do
    let(:transaction) { new_transaction }
    let(:env) { http_request_env_with_data }
    let(:error) do
      ExampleStandardError.new("test message").tap do |e|
        e.set_backtrace(["line 1"])
      end
    end

    # The completed root span's sole `exception` span-event.
    def exception_event
      root_span.events.find { |event| event.name == "exception" }
    end

    it "responds to add_exception for backwards compatibility" do
      expect(transaction).to respond_to(:add_exception)
    end

    it "does not add the error to the errors" do
      transaction.send(:_set_error, error)

      expect(transaction.error_blocks).to be_empty
    end

    context "for a http request" do
      it "sets an error on the transaction" do
        transaction.send(:_set_error, error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "test message",
          ["line 1"]
        )
      end
    end

    context "when the error has no causes" do
      it "should set an empty causes array as sample data", :agent_mode do
        start_agent(**start_agent_args)
        transaction.send(:_set_error, error)

        expect(transaction).to include_error_causes([])
      end

      it "sets no error causes attribute in collector mode", :collector_mode do
        start_collector_agent
        transaction.send(:_set_error, error)
        transaction.complete

        expect(exception_event.attributes).not_to have_key("appsignal.error_causes")
      end
    end

    context "when the error has multiple causes" do
      let(:error) do
        e = ExampleStandardError.new("test message")
        e.set_backtrace([
          "/absolute/path/example.rb:9123:in `my_method'",
          "/absolute/path/context.rb:9456:in `context_method'",
          "/absolute/path/suite.rb:9789:in `suite_method'"
        ])
        e2 = RuntimeError.new("cause message")
        e2.set_backtrace([
          # Absolute path with gem name
          "my_gem (1.2.3) /absolute/path/example.rb:123:in `my_method'",
          "other_gem (4.5.6) /absolute/path/context.rb:456:in `context_method'",
          "other_gem (4.5.6) /absolute/path/suite.rb:789:in `suite_method'"
        ])
        e3 = StandardError.new("cause message 2")
        e3.set_backtrace([
          # Relative paths
          "src/example.rb:123:in `my_method'",
          "context.rb:456:in `context_method'",
          "suite.rb:789:in `suite_method'"
        ])
        e4 = StandardError.new("cause message 3")
        e4.set_backtrace([]) # No backtrace

        allow(e).to receive(:cause).and_return(e2)
        allow(e2).to receive(:cause).and_return(e3)
        allow(e3).to receive(:cause).and_return(e4)
        e
      end
      let(:error_without_cause) do
        ExampleStandardError.new("error without cause")
      end
      let(:options) { { :revision => "my_revision" } }

      it "sends the error causes information as sample data", :agent_mode do
        start_agent(**start_agent_args)
        # Hide Rails so we can test the normal Ruby behavior. The Rails
        # behavior is tested in another spec.
        hide_const("Rails")

        transaction.send(:_set_error, error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "test message",
          [
            "/absolute/path/example.rb:9123:in `my_method'",
            "/absolute/path/context.rb:9456:in `context_method'",
            "/absolute/path/suite.rb:9789:in `suite_method'"
          ]
        )
        expect(transaction).to include_error_causes(
          [
            {
              "name" => "RuntimeError",
              "message" => "cause message",
              "first_line" => {
                "original" => "my_gem (1.2.3) /absolute/path/example.rb:123:in `my_method'",
                "gem" => "my_gem (1.2.3)",
                "path" => "/absolute/path/example.rb",
                "line" => 123,
                "method" => "my_method",
                "revision" => "my_revision"
              }
            },
            {
              "name" => "StandardError",
              "message" => "cause message 2",
              "first_line" => {
                "original" => "src/example.rb:123:in `my_method'",
                "gem" => nil,
                "path" => "src/example.rb",
                "line" => 123,
                "method" => "my_method",
                "revision" => "my_revision"
              }
            },
            {
              "name" => "StandardError",
              "message" => "cause message 3",
              "first_line" => nil
            }
          ]
        )
      end

      # The collector-mode cause channel is `appsignal.error_causes`, which
      # carries the full cleaned backtrace per cause (`lines`) rather than the
      # agent's `first_line`-only projection.
      it "records the error causes on the exception event in collector mode", :collector_mode do
        start_collector_agent
        hide_const("Rails")

        transaction.send(:_set_error, error)
        transaction.complete

        expect(JSON.parse(exception_event.attributes["appsignal.error_causes"])).to eq(
          [
            {
              "name" => "RuntimeError",
              "message" => "cause message",
              "lines" => [
                "my_gem (1.2.3) /absolute/path/example.rb:123:in `my_method'",
                "other_gem (4.5.6) /absolute/path/context.rb:456:in `context_method'",
                "other_gem (4.5.6) /absolute/path/suite.rb:789:in `suite_method'"
              ]
            },
            {
              "name" => "StandardError",
              "message" => "cause message 2",
              "lines" => [
                "src/example.rb:123:in `my_method'",
                "context.rb:456:in `context_method'",
                "suite.rb:789:in `suite_method'"
              ]
            },
            {
              "name" => "StandardError",
              "message" => "cause message 3",
              "lines" => []
            }
          ]
        )
      end

      it "does not keep error causes from previously set errors" do
        transaction.send(:_set_error, error)
        transaction.send(:_set_error, error_without_cause)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "error without cause",
          []
        )

        expect(transaction).to include_error_causes([])
      end

      describe "with app paths" do
        let(:root_path) { project_fixture_path }
        let(:error) do
          e = ExampleStandardError.new("test message")
          e2 = RuntimeError.new("cause message")
          e2.set_backtrace(["#{root_path}/src/example.rb:123:in `my_method'"])
          allow(e).to receive(:cause).and_return(e2)
          e
        end

        it "sends the error causes information as sample data" do
          # Hide Rails so we can test the normal Ruby behavior. The Rails
          # behavior is tested in another spec.
          hide_const("Rails")

          transaction.send(:_set_error, error)

          path = "src/example.rb"
          original_path = "#{root_path}/#{path}"

          expect(transaction).to include_error_causes([
            {
              "name" => "RuntimeError",
              "message" => "cause message",
              "first_line" => {
                "original" => "#{original_path}:123:in `my_method'",
                "gem" => nil,
                "path" => path,
                "line" => 123,
                "method" => "my_method",
                "revision" => "my_revision"
              }
            }
          ])
        end
      end

      if rails_present?
        describe "with Rails" do
          let(:root_path) { project_fixture_path }
          let(:error) do
            e = ExampleStandardError.new("test message")
            e2 = RuntimeError.new("cause message")
            e2.set_backtrace([
              "#{root_path}/src/example.rb:123:in `my_method'"
            ])
            allow(e).to receive(:cause).and_return(e2)
            e
          end

          it "sends the causes information as sample data" do
            transaction.send(:_set_error, error)

            path = "src/example.rb"
            original_path = "#{root_path}/#{path}"
            # When Rails is present we run it through the Rails backtrace cleaner
            # that removes the app path from the backtrace lines, so update our
            # assertion to match.
            original_path.delete_prefix!(DirectoryHelper.project_dir)
            original_path.delete_prefix!("/")
            path = original_path

            expect(transaction).to include_error_causes([
              {
                "name" => "RuntimeError",
                "message" => "cause message",
                "first_line" => {
                  "original" => "#{original_path}:123:in `my_method'",
                  "gem" => nil,
                  "path" => path,
                  "line" => 123,
                  "method" => "my_method",
                  "revision" => "my_revision"
                }
              }
            ])
          end
        end
      end

      describe "HAML backtrace lines" do
        let(:error) do
          e = ExampleStandardError.new("test message")
          e2 = RuntimeError.new("cause message")
          e2.set_backtrace([
            "app/views/search/_navigation_tabs.html.haml:17"
          ])
          allow(e).to receive(:cause).and_return(e2)
          e
        end

        it "sends the causes information as sample data" do
          transaction.send(:_set_error, error)

          expect(transaction).to include_error_causes(
            [
              {
                "name" => "RuntimeError",
                "message" => "cause message",
                "first_line" => {
                  "original" => "app/views/search/_navigation_tabs.html.haml:17",
                  "gem" => nil,
                  "path" => "app/views/search/_navigation_tabs.html.haml",
                  "line" => 17,
                  "method" => nil,
                  "revision" => "my_revision"
                }
              }
            ]
          )
        end
      end

      describe "invalid backtrace lines" do
        let(:error) do
          e = ExampleStandardError.new("test message")
          e.set_backtrace([
            "/absolute/path/example.rb:9123:in `my_method'",
            "/absolute/path/context.rb:9456:in `context_method'",
            "/absolute/path/suite.rb:9789:in `suite_method'"
          ])
          e2 = RuntimeError.new("cause message")
          e2.set_backtrace([
            "(lorem) abc def xyz.123 `function yes '"
          ])
          allow(e).to receive(:cause).and_return(e2)
          e
        end

        it "doesn't send the cause line information as sample data" do
          transaction.send(:_set_error, error)

          expect(transaction).to include_error_causes(
            [
              {
                "name" => "RuntimeError",
                "message" => "cause message",
                "first_line" => nil
              }
            ]
          )
        end
      end
    end

    context "when the error has too many causes" do
      let(:error) do
        e = ExampleStandardError.new("root cause error")

        11.times do |i|
          next_e = ExampleStandardError.new("wrapper error #{i}")
          allow(next_e).to receive(:cause).and_return(e)
          e = next_e
        end
        e.set_backtrace(["line 1"])
        e
      end

      it "sends only the first causes as sample data", :agent_mode do
        start_agent(**start_agent_args)
        expected_error_causes =
          Array.new(10) do |i|
            {
              "name" => "ExampleStandardError",
              "message" => "wrapper error #{9 - i}",
              "first_line" => nil
            }
          end
        expected_error_causes.last["is_root_cause"] = false

        logs = capture_logs { transaction.send(:_set_error, error) }

        expect(transaction).to have_error(
          "ExampleStandardError",
          "wrapper error 10",
          ["line 1"]
        )
        expect(transaction).to include_error_causes(expected_error_causes)
        expect(logs).to contains_log(
          :debug,
          "Appsignal::Transaction#add_error: Error has more " \
            "than 10 error causes. Only the first 10 " \
            "will be reported."
        )
      end

      it "records only the first causes on the exception event in collector mode",
        :collector_mode do
        start_collector_agent
        expected_error_causes =
          Array.new(10) do |i|
            {
              "name" => "ExampleStandardError",
              "message" => "wrapper error #{9 - i}",
              "lines" => []
            }
          end

        logs = capture_logs do
          transaction.send(:_set_error, error)
          transaction.complete
        end

        expect(JSON.parse(exception_event.attributes["appsignal.error_causes"]))
          .to eq(expected_error_causes)
        expect(logs).to contains_log(
          :debug,
          "Appsignal::Transaction#add_error: Error has more " \
            "than 10 error causes. Only the first 10 " \
            "will be reported."
        )
      end
    end

    context "when error message is nil" do
      let(:error) do
        e = ExampleStandardError.new
        allow(e).to receive(:message).and_return(nil)
        e.set_backtrace(["line 1"])
        e
      end

      it "does not raise an error" do
        transaction.send(:_set_error, error)
      end

      it "sets an error on the transaction without an error message", :agent_mode do
        start_agent(**start_agent_args)
        transaction.send(:_set_error, error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "",
          ["line 1"]
        )
      end

      it "records an empty error message on the exception event in collector mode",
        :collector_mode do
        start_collector_agent
        transaction.send(:_set_error, error)
        transaction.complete

        expect(exception_event.attributes["exception.type"]).to eq("ExampleStandardError")
        expect(exception_event.attributes["exception.message"]).to eq("")
      end
    end
  end

  describe "#after_create" do
    it "stores the given hook when passed as a block" do
      transaction = new_transaction

      expect(Appsignal::Transaction.after_create).to be_empty
      Appsignal::Transaction.after_create do |t|
        t.set_action("hook_action")
      end

      expect(Appsignal::Transaction.after_create).to_not be_empty

      expect(transaction).to_not have_action("hook_action")
      Appsignal::Transaction.after_create.first.call(transaction)
      expect(transaction).to have_action("hook_action")
    end

    it "stores the given hook when using <<" do
      expect(Appsignal::Transaction.after_create).to be_empty
      proc = proc do |transaction|
        transaction.set_action("hook_action")
      end

      Appsignal::Transaction.after_create << proc

      expect(Appsignal::Transaction.after_create).to eq(Set.new([proc]))
    end

    it "only stores a hook once when added several times" do
      expect(Appsignal::Transaction.after_create).to be_empty
      proc = proc do |transaction|
        transaction.set_action("hook_action")
      end

      Appsignal::Transaction.after_create(&proc)
      Appsignal::Transaction.after_create << proc

      expect(Appsignal::Transaction.after_create).to eq(Set.new([proc]))
    end

    it "calls the given hook when a transaction is created" do
      block = proc do |transaction|
        transaction.set_action("hook_action")
      end

      Appsignal::Transaction.after_create(&block)

      expect(block).to(
        receive(:call)
          .with(kind_of(Appsignal::Transaction))
          .and_call_original
      )

      expect(new_transaction).to have_action("hook_action")
    end

    it "calls all the hooks in order" do
      Appsignal::Transaction.after_create do |transaction|
        transaction.set_namespace("hook_namespace_1")
        transaction.set_action("hook_action_1")
      end

      Appsignal::Transaction.after_create do |transaction|
        transaction.set_action("hook_action_2")
      end

      transaction = new_transaction

      expect(transaction).to have_namespace("hook_namespace_1")
      expect(transaction).to have_action("hook_action_2")
    end
  end

  describe "#before_complete" do
    it "stores the given hook when passed as a block" do
      expect(Appsignal::Transaction.before_complete).to be_empty
      Appsignal::Transaction.before_complete do |transaction, error|
        transaction.set_action(error.message)
      end

      expect(Appsignal::Transaction.before_complete).to_not be_empty

      transaction = new_transaction
      error = ExampleStandardError.new("hook_error")

      expect(transaction).to_not have_action("hook_error")
      Appsignal::Transaction.before_complete.first.call(transaction, error)
      expect(transaction).to have_action("hook_error")
    end

    it "stores the given hook when using <<" do
      expect(Appsignal::Transaction.before_complete).to be_empty
      proc = proc do |transaction, error|
        transaction.set_action(error.message)
      end

      Appsignal::Transaction.before_complete << proc

      expect(Appsignal::Transaction.before_complete).to eq(Set.new([proc]))
    end

    it "only stores a hook once when added several times" do
      expect(Appsignal::Transaction.before_complete).to be_empty
      proc = proc do |transaction|
        transaction.set_action("hook_action")
      end

      Appsignal::Transaction.before_complete(&proc)
      Appsignal::Transaction.before_complete << proc

      expect(Appsignal::Transaction.before_complete).to eq(Set.new([proc]))
    end

    context "when the transaction has an error" do
      it "calls the given hook with the error when a transaction is completed" do
        block = proc do |transaction, error|
          transaction.set_action(error.message)
        end

        Appsignal::Transaction.before_complete(&block)

        transaction = new_transaction
        error = ExampleStandardError.new("hook_error")
        transaction.set_error(error)

        expect(block).to(
          receive(:call)
            .with(transaction, error)
            .and_call_original
        )

        transaction.complete

        expect(transaction).to have_action("hook_error")
      end
    end

    context "when the transaction has several errors" do
      it "calls the given hook for each of the duplicate error transactions", :agent_mode do
        start_agent(**start_agent_args)
        block = proc do |transaction, error|
          transaction.set_action(error.message)
        end

        Appsignal::Transaction.before_complete(&block)

        transaction = new_transaction
        first_error = ExampleStandardError.new("hook_error_first")
        transaction.set_error(first_error)

        second_error = ExampleStandardError.new("hook_error_second")
        transaction.set_error(second_error)

        transaction.complete

        expect(created_transactions.length).to eq(2)

        expect(created_transactions.find { |t| t == transaction }).to(
          have_action("hook_error_first")
        )
        expect(created_transactions.find { |t| t != transaction }).to(
          have_action("hook_error_second")
        )
      end

      it "calls the hook once with the first error in collector mode", :collector_mode do
        start_collector_agent
        block = proc do |transaction, error|
          transaction.set_action(error.message)
        end

        Appsignal::Transaction.before_complete(&block)

        transaction = new_transaction
        transaction.set_error(ExampleStandardError.new("hook_error_first"))
        transaction.set_error(ExampleStandardError.new("hook_error_second"))

        expect(block).to receive(:call).once.and_call_original

        transaction.complete

        # One trace, so the hook runs once with the first error.
        expect(root_span.name).to eq("hook_error_first")
      end
    end

    context "when the transaction does not have an error" do
      it "calls the given hook with nil when a transaction is completed" do
        block = proc do |transaction|
          transaction.set_action("hook_action")
        end

        Appsignal::Transaction.before_complete(&block)

        transaction = new_transaction

        expect(block).to(
          receive(:call)
            .with(transaction, nil)
            .and_call_original
        )

        transaction.complete

        expect(transaction).to have_action("hook_action")
      end
    end

    it "calls all the hooks in order" do
      Appsignal::Transaction.before_complete do |transaction, error|
        transaction.set_namespace(error.message)
        transaction.set_action("hook_action_1")
      end

      Appsignal::Transaction.before_complete do |transaction, error|
        transaction.set_action(error.message)
      end

      transaction = new_transaction
      error = ExampleStandardError.new("hook_error")
      transaction.set_error(error)

      transaction.complete

      expect(transaction).to have_namespace("hook_error")
      expect(transaction).to have_action("hook_error")
    end
  end

  describe "#start_event" do
    let(:transaction) { new_transaction }

    it "starts the event in the extension" do
      expect(transaction.backend).to receive(:start_event).with(0).and_call_original

      transaction.start_event
    end

    context "when transaction is paused" do
      it "does not start the event" do
        transaction.pause!
        expect(transaction.backend).to_not receive(:start_event)

        transaction.start_event
      end
    end
  end

  describe "#finish_event" do
    let(:transaction) { new_transaction }
    let(:fake_gc_time) { 0 }

    it "should finish the event in the extension" do
      expect(transaction.backend).to receive(:finish_event).with(
        "name",
        "title",
        "body",
        1,
        fake_gc_time
      ).and_call_original

      transaction.finish_event(
        "name",
        "title",
        "body",
        1
      )
    end

    it "should finish the event in the extension with nil arguments" do
      expect(transaction.backend).to receive(:finish_event).with(
        "name",
        "",
        "",
        0,
        fake_gc_time
      ).and_call_original

      transaction.finish_event(
        "name",
        nil,
        nil,
        nil
      )
    end

    context "when transaction is paused" do
      it "does not finish the event" do
        transaction.pause!
        expect(transaction.backend).to_not receive(:finish_event)

        transaction.start_event
      end
    end
  end

  describe "#record_event" do
    let(:transaction) { new_transaction }
    let(:fake_gc_time) { 0 }

    it "should record the event in the extension" do
      expect(transaction.backend).to receive(:record_event).with(
        "name",
        "title",
        "body",
        1,
        1000,
        fake_gc_time
      ).and_call_original

      transaction.record_event(
        "name",
        "title",
        "body",
        1000,
        1
      )
    end

    it "should finish the event in the extension with nil arguments" do
      expect(transaction.backend).to receive(:record_event).with(
        "name",
        "",
        "",
        0,
        1000,
        fake_gc_time
      ).and_call_original

      transaction.record_event(
        "name",
        nil,
        nil,
        1000,
        nil
      )
    end

    context "when transaction is paused" do
      it "does not record the event" do
        transaction.pause!
        expect(transaction.backend).to_not receive(:record_event)

        transaction.record_event(
          "name",
          nil,
          nil,
          1000,
          nil
        )
      end
    end

    describe "recording an event with the given duration" do
      let(:duration_ns) { 1_000_000_000 }

      def perform(transaction)
        transaction.record_event("custom.event", "T", "B", duration_ns,
          Appsignal::EventFormatter::DEFAULT)
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        expect(transaction).to include_event(
          "name" => "custom.event",
          "title" => "T",
          "body" => "B"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        span = event_spans.first
        expect(span.name).to eq("T")
        expect(span.attributes["appsignal.category"]).to eq("custom.event")
        expect(span.parent_span_id).to eq(root_span.span_id)
        observed = span.end_timestamp - span.start_timestamp
        expect(observed).to be_within(50_000_000).of(duration_ns)
      end
    end
  end

  describe "#instrument" do
    it_behaves_like "instrument helper" do
      let(:transaction) { new_transaction }
      let(:instrumenter) { transaction }
    end

    describe "block return value" do
      it_in_both_modes do
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        result = transaction.instrument("sql.active_record", "Query", "SELECT 1",
          Appsignal::EventFormatter::SQL_BODY_FORMAT) { 42 }

        expect(result).to eq(42)
      end
    end

    describe "block raising an exception" do
      it_in_both_modes do
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)

        expect do
          transaction.instrument("x.y", nil, nil, Appsignal::EventFormatter::DEFAULT) do
            raise "boom"
          end
        end.to raise_error("boom")
      end
    end

    describe "instrumenting a SQL event" do
      def perform(transaction)
        transaction.instrument("sql.active_record", "Query", "SELECT 1",
          Appsignal::EventFormatter::SQL_BODY_FORMAT) { nil }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        expect(transaction).to include_event(
          "name" => "sql.active_record",
          "title" => "Query",
          "body" => "SELECT 1",
          "body_format" => Appsignal::EventFormatter::SQL_BODY_FORMAT
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        span = event_spans.first
        expect(span.name).to eq("Query")
        expect(span.parent_span_id).to eq(root_span.span_id)
        expect(span.attributes).to include(
          "db.query.text" => "SELECT 1",
          "db.system.name" => "other_sql",
          "appsignal.category" => "sql.active_record"
        )
        expect(span.attributes).not_to have_key("appsignal.body")
      end
    end

    describe "instrumenting a default-format event" do
      def perform(transaction)
        transaction.instrument("custom.event", "Title", "Body",
          Appsignal::EventFormatter::DEFAULT) { nil }
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        expect(transaction).to include_event(
          "name" => "custom.event",
          "title" => "Title",
          "body" => "Body",
          "body_format" => Appsignal::EventFormatter::DEFAULT
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        span = event_spans.first
        expect(span.name).to eq("Title")
        expect(span.attributes).to include(
          "appsignal.body" => "Body",
          "appsignal.category" => "custom.event"
        )
        expect(span.attributes).not_to have_key("db.query.text")
        expect(span.attributes).not_to have_key("db.system.name")
      end
    end

    describe "nesting instrumented events" do
      def perform(transaction)
        transaction.instrument("outer.event", "Outer", "outer body",
          Appsignal::EventFormatter::DEFAULT) do
          transaction.instrument("inner.event", "Inner", "inner body",
            Appsignal::EventFormatter::DEFAULT) { nil }
        end
      end

      it "in agent mode", :agent_mode do
        start_agent(**start_agent_args)
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        expect(transaction).to include_event(
          "name" => "outer.event", "title" => "Outer", "body" => "outer body"
        )
        expect(transaction).to include_event(
          "name" => "inner.event", "title" => "Inner", "body" => "inner body"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        perform(transaction)
        Appsignal::Transaction.complete_current!

        outer = event_spans.find { |s| s.attributes["appsignal.category"] == "outer.event" }
        inner = event_spans.find { |s| s.attributes["appsignal.category"] == "inner.event" }

        expect(inner.parent_span_id).to eq(outer.span_id)
        expect(outer.parent_span_id).to eq(root_span.span_id)
      end
    end

    describe "with an empty title" do
      it "names the span after the event name and omits appsignal.title", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        transaction.instrument("custom.event", nil, "Body",
          Appsignal::EventFormatter::DEFAULT) { nil }
        Appsignal::Transaction.complete_current!

        span = event_spans.first
        expect(span.name).to eq("custom.event")
        expect(span.attributes["appsignal.category"]).to eq("custom.event")
        expect(span.attributes).not_to have_key("appsignal.title")
      end
    end

    describe "with an empty body" do
      it "omits the body attribute on the span", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        transaction.instrument("custom.event", "Title", nil,
          Appsignal::EventFormatter::DEFAULT) { nil }
        Appsignal::Transaction.complete_current!

        attrs = event_spans.first.attributes
        expect(attrs).not_to have_key("appsignal.body")
        expect(attrs).not_to have_key("db.query.text")
      end
    end

    describe "OpenTelemetry current context during the block" do
      it "in collector mode", :collector_mode do
        start_collector_agent
        transaction = create_transaction(Appsignal::Transaction::HTTP_REQUEST)
        root_span_id = ::OpenTelemetry::Trace.current_span.context.span_id

        event_span_id_during_block = nil
        transaction.instrument("custom.event", "T", "B", Appsignal::EventFormatter::DEFAULT) do
          event_span_id_during_block = ::OpenTelemetry::Trace.current_span.context.span_id
        end

        expect(event_span_id_during_block).not_to eq(root_span_id)
        expect(::OpenTelemetry::Trace.current_span.context.span_id).to eq(root_span_id)
      end
    end
  end

  # private

  describe ".to_hash / .to_h" do
    let(:transaction) { new_transaction }
    subject { transaction.to_hash }

    context "when extension returns serialized JSON" do
      it "parses the result and returns a Hash" do
        expect(subject).to include(
          "action" => nil,
          "error" => nil,
          "events" => [],
          "id" => kind_of(String),
          "metadata" => {},
          "namespace" => default_namespace,
          "sample_data" => {}
        )
      end
    end

    context "when the extension returns invalid serialized JSON" do
      before do
        expect(transaction.backend).to receive(:to_json).and_return("foo")
      end

      it "raises a JSON parse error" do
        expect { subject }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe Appsignal::Transaction::NilTransaction do
    subject { Appsignal::Transaction::NilTransaction.new }

    it "has method stubs" do
      subject.complete
      subject.pause!
      subject.resume!
      subject.paused?
      subject.store(:key)
      subject.add_tags(:tag => 1)
      subject.set_action("action")
      subject.set_http_or_background_action
      subject.set_queue_start(1)
      subject.set_http_or_background_queue_start
      subject.set_metadata("key", "value")
      subject.set_sample_data("key", "data")
      subject._sample
      subject.set_error("a")
    end
  end
end
