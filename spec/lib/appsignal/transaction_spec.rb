describe Appsignal::Transaction do
  let(:options) { {} }
  let(:time) { Time.at(fixed_time) }
  let(:root_path) { nil }

  before do
    start_agent(:options => options, :root_path => root_path)
    Timecop.freeze(time)
  end
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

    context "when an explicit extension transaction is passed in the initialiser" do
      let(:ext) { "some_ext" }

      it "assigns the extension transaction to the transaction" do
        expect(described_class.new("web", :ext => ext).ext).to be(ext)
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
      it "does not complete the transaction" do
        expect do
          transaction.discard!
        end.to change { transaction.discarded? }.from(false).to(true)

        transaction.complete

        expect(transaction).to_not be_completed
      end

      it "logs a debug message" do
        allow(SecureRandom).to receive(:uuid).and_return("mock_transaction_id")
        transaction.discard!
        logs = capture_logs { transaction.complete }

        expect(logs).to contains_log :debug,
          "Skipping transaction 'mock_transaction_id' because it was manually discarded."
      end

      context "when a discarded transaction is restored" do
        before { transaction.discard! }

        it "completes the transaction" do
          expect do
            transaction.restore!
          end.to change { transaction.discarded? }.from(true).to(false)

          transaction.complete

          expect(transaction).to be_completed
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

          expect(original_transaction.ext).to_not eq(duplicate_transaction.ext)
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
      expect(transaction.ext).to_not be_nil
    end

    context "when extension is not loaded", :extension_installation_failure do
      around do |example|
        Appsignal::Testing.without_testing { example.run }
      end

      it "does not error on missing extension method calls" do
        expect(transaction.ext).to be_kind_of(Appsignal::Extension::MockTransaction)
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

    it "adds the params to the transaction" do
      params = { "key" => "value" }
      transaction.add_params(params)

      transaction._sample
      expect(transaction).to include_params(params)
    end

    it "merges the params on the transaction" do
      transaction.add_params("abc" => "value")
      transaction.add_params("def" => "value")
      transaction.add_params { { "xyz" => "value" } }

      transaction._sample
      expect(transaction).to include_params(
        "abc" => "value",
        "def" => "value",
        "xyz" => "value"
      )
    end

    it "adds the params to the transaction with a block" do
      params = { "key" => "value" }
      transaction.add_params { params }

      transaction._sample
      expect(transaction).to include_params(params)
    end

    it "adds the params block value when both an argument and block are given" do
      arg_params = { "argument" => "value" }
      block_params = { "block" => "value" }
      transaction.add_params(arg_params) { block_params }

      transaction._sample
      expect(transaction).to include_params(block_params)
    end

    it "logs an error if an error occurred storing the params" do
      transaction.add_params { raise "uh oh" }

      logs = capture_logs { transaction._sample }
      expect(logs).to contains_log(
        :error,
        "Exception while fetching params: RuntimeError: uh oh"
      )
    end

    it "does not update the params on the transaction if the given value is nil" do
      params = { "key" => "value" }
      transaction.add_params(params)
      transaction.add_params(nil)

      transaction._sample
      expect(transaction).to include_params(params)
    end

    context "with AppSignal filtering" do
      let(:options) { { :filter_parameters => %w[foo] } }

      it "returns sanitized custom params" do
        transaction.add_params("foo" => "value", "baz" => "bat")

        transaction._sample
        expect(transaction).to include_params("foo" => "[FILTERED]", "baz" => "bat")
      end
    end
  end

  describe "#add_params_if_nil" do
    let(:transaction) { new_transaction }

    it "has a #set_params_if_nil alias" do
      expect(transaction.method(:add_params_if_nil)).to eq(transaction.method(:set_params_if_nil))
    end

    context "when the params are not set" do
      it "adds the params to the transaction" do
        params = { "key" => "value" }
        transaction.add_params_if_nil(params)

        transaction._sample
        expect(transaction).to include_params(params)
      end

      it "adds the params to the transaction with a block" do
        params = { "key" => "value" }
        transaction.add_params_if_nil { params }

        transaction._sample
        expect(transaction).to include_params(params)
      end

      it "adds the params block value when both an argument and block are given" do
        arg_params = { "argument" => "value" }
        block_params = { "block" => "value" }
        transaction.add_params_if_nil(arg_params) { block_params }

        transaction._sample
        expect(transaction).to include_params(block_params)
      end

      it "does not update the params on the transaction if the given value is nil" do
        params = { "key" => "value" }
        transaction.add_params(params)
        transaction.add_params_if_nil(nil)

        transaction._sample
        expect(transaction).to include_params(params)
      end
    end

    context "when the params are set" do
      it "does not update the params on the transaction" do
        preset_params = { "other" => "params" }
        params = { "key" => "value" }
        transaction.add_params(preset_params)
        transaction.add_params_if_nil(params)

        transaction._sample
        expect(transaction).to include_params(preset_params)
      end

      it "does not update the params with a block on the transaction" do
        preset_params = { "other" => "params" }
        params = { "key" => "value" }
        transaction.add_params(preset_params)
        transaction.add_params_if_nil { params }

        transaction._sample
        expect(transaction).to include_params(preset_params)
      end
    end

    context "when the params were set as an empty value" do
      it "does not set params on the transaction" do
        transaction.add_params("key1" => "value")
        transaction.set_empty_params!
        transaction.add_params_if_nil("key2" => "value")

        transaction._sample
        expect(transaction).to_not include_params
      end
    end
  end

  describe "#add_session_data" do
    let(:transaction) { new_transaction }

    it "has a #set_session_data alias" do
      expect(transaction.method(:add_session_data)).to eq(transaction.method(:set_session_data))
    end

    it "adds the session data to the transaction" do
      data = { "key" => "value" }
      transaction.add_session_data(data)

      transaction._sample
      expect(transaction).to include_session_data(data)
    end

    it "merges the session data on the transaction" do
      transaction.add_session_data("abc" => "value")
      transaction.add_session_data("def" => "value")
      transaction.add_session_data { { "xyz" => "value" } }

      transaction._sample
      expect(transaction).to include_session_data(
        "abc" => "value",
        "def" => "value",
        "xyz" => "value"
      )
    end

    it "adds the session data to the transaction with a block" do
      data = { "key" => "value" }
      transaction.add_session_data { data }

      transaction._sample
      expect(transaction).to include_session_data(data)
    end

    it "adds the session data block value when both an argument and block are given" do
      arg_data = { "argument" => "value" }
      block_data = { "block" => "value" }
      transaction.add_session_data(arg_data) { block_data }

      transaction._sample
      expect(transaction).to include_session_data(block_data)
    end

    it "adds certain Ruby objects as Strings" do
      transaction.add_session_data("time" => Time.utc(2024, 9, 12, 13, 14, 15))
      transaction.add_session_data("date" => Date.new(2024, 9, 11))

      transaction._sample
      expect(transaction).to include_session_data(
        "time" => "#<Time: 2024-09-12T13:14:15Z>",
        "date" => "#<Date: 2024-09-11>"
      )
    end

    it "logs an error if an error occurred storing the session data" do
      transaction.add_session_data { raise "uh oh" }

      logs = capture_logs { transaction._sample }
      expect(logs).to contains_log(
        :error,
        "Exception while fetching session data: RuntimeError: uh oh"
      )
    end

    it "does not update the session data on the transaction if the given value is nil" do
      data = { "key" => "value" }
      transaction.add_session_data(data)
      transaction.add_session_data(nil)

      transaction._sample
      expect(transaction).to include_session_data(data)
    end

    context "with filter_session_data" do
      let(:options) { { :filter_session_data => ["filtered_key"] } }

      it "does not include filtered out session data" do
        transaction.add_session_data("data" => "value1", "filtered_key" => "filtered_value")

        transaction._sample
        expect(transaction).to include_session_data("data" => "value1")
      end
    end
  end

  describe "#add_session_data_if_nil" do
    let(:transaction) { new_transaction }

    context "when the session data is not set" do
      it "sets the session data on the transaction" do
        data = { "key" => "value" }
        transaction.add_session_data_if_nil(data)

        transaction._sample
        expect(transaction).to include_session_data(data)
      end

      it "updates the session data on the transaction with a block" do
        data = { "key" => "value" }
        transaction.add_session_data_if_nil { data }

        transaction._sample
        expect(transaction).to include_session_data(data)
      end

      it "updates with the session data block when both an argument and block are given" do
        arg_data = { "argument" => "value" }
        block_data = { "block" => "value" }
        transaction.add_session_data_if_nil(arg_data) { block_data }

        transaction._sample
        expect(transaction).to include_session_data(block_data)
      end

      it "does not update the session data on the transaction if the given value is nil" do
        data = { "key" => "value" }
        transaction.add_session_data(data)
        transaction.add_session_data_if_nil(nil)

        transaction._sample
        expect(transaction).to include_session_data(data)
      end
    end

    context "when the session data are set" do
      it "does not update the session data on the transaction" do
        preset_data = { "other" => "data" }
        data = { "key" => "value" }
        transaction.add_session_data(preset_data)
        transaction.add_session_data_if_nil(data)

        transaction._sample
        expect(transaction).to include_session_data(preset_data)
      end

      it "does not update the session data with a block on the transaction" do
        preset_data = { "other" => "data" }
        data = { "key" => "value" }
        transaction.add_session_data(preset_data)
        transaction.add_session_data_if_nil { data }

        transaction._sample
        expect(transaction).to include_session_data(preset_data)
      end
    end
  end

  describe "#add_headers" do
    let(:transaction) { new_transaction }

    it "has a #set_headers alias" do
      expect(transaction.method(:add_headers)).to eq(transaction.method(:set_headers))
    end

    it "adds the headers to the transaction" do
      headers = { "PATH_INFO" => "value" }
      transaction.add_headers(headers)

      transaction._sample
      expect(transaction).to include_environment(headers)
    end

    it "merges the headers on the transaction" do
      transaction.add_headers("PATH_INFO" => "value")
      transaction.add_headers("REQUEST_METHOD" => "value")
      transaction.add_headers { { "HTTP_ACCEPT" => "value" } }

      transaction._sample
      expect(transaction).to include_environment(
        "PATH_INFO" => "value",
        "REQUEST_METHOD" => "value",
        "HTTP_ACCEPT" => "value"
      )
    end

    it "adds the headers to the transaction with a block" do
      headers = { "PATH_INFO" => "value" }
      transaction.add_headers { headers }

      transaction._sample
      expect(transaction).to include_environment(headers)
    end

    it "adds the headers block value when both an argument and block are given" do
      arg_data = { "PATH_INFO" => "/arg-path" }
      block_data = { "PATH_INFO" => "/block-path" }
      transaction.add_headers(arg_data) { block_data }

      transaction._sample
      expect(transaction).to include_environment(block_data)
    end

    it "logs an error if an error occurred storing the headers" do
      transaction.add_headers { raise "uh oh" }

      logs = capture_logs { transaction._sample }
      expect(logs).to contains_log(
        :error,
        "Exception while fetching headers: RuntimeError: uh oh"
      )
    end

    it "does not update the headers on the transaction if the given value is nil" do
      headers = { "PATH_INFO" => "value" }
      transaction.add_headers(headers)
      transaction.add_headers(nil)

      transaction._sample
      expect(transaction).to include_environment(headers)
    end

    context "with request_headers options" do
      let(:options) { { :request_headers => ["MY_HEADER"] } }

      it "does not include filtered out headers" do
        transaction.add_headers("MY_HEADER" => "value1", "filtered_key" => "filtered_value")

        transaction._sample
        expect(transaction).to include_environment("MY_HEADER" => "value1")
      end
    end
  end

  describe "#add_headers_if_nil" do
    let(:transaction) { new_transaction }

    it "has a #set_headers_if_nil alias" do
      expect(transaction.method(:add_headers_if_nil)).to eq(transaction.method(:set_headers_if_nil))
    end

    context "when the headers are not set" do
      it "adds the headers to the transaction" do
        headers = { "PATH_INFO" => "value" }
        transaction.add_headers_if_nil(headers)

        transaction._sample
        expect(transaction).to include_environment(headers)
      end

      it "adds the headers to the transaction with a block" do
        headers = { "PATH_INFO" => "value" }
        transaction.add_headers_if_nil { headers }

        transaction._sample
        expect(transaction).to include_environment(headers)
      end

      it "adds the headers block value when both an argument and block are given" do
        arg_data = { "PATH_INFO" => "/arg-path" }
        block_data = { "PATH_INFO" => "/block-path" }
        transaction.add_headers_if_nil(arg_data) { block_data }

        transaction._sample
        expect(transaction).to include_environment(block_data)
      end

      it "does not update the headers on the transaction if the given value is nil" do
        headers = { "PATH_INFO" => "value" }
        transaction.add_headers(headers)
        transaction.add_headers_if_nil(nil)

        transaction._sample
        expect(transaction).to include_environment(headers)
      end
    end

    context "when the headers are set" do
      it "does not update the headers on the transaction" do
        preset_headers = { "PATH_INFO" => "/first-path" }
        headers = { "PATH_INFO" => "/other-path" }
        transaction.add_headers(preset_headers)
        transaction.add_headers_if_nil(headers)

        transaction._sample
        expect(transaction).to include_environment(preset_headers)
      end

      it "does not update the headers with a block on the transaction" do
        preset_headers = { "PATH_INFO" => "/first-path" }
        headers = { "PATH_INFO" => "/other-path" }
        transaction.add_headers(preset_headers)
        transaction.add_headers_if_nil { headers }

        transaction._sample
        expect(transaction).to include_environment(preset_headers)
      end
    end
  end

  describe "#add_tags" do
    let(:transaction) { new_transaction }
    let(:long_string) { "a" * 10_001 }

    it "stores tags on the transaction" do
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
      transaction._sample

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

    it "merges the tags when called multiple times" do
      transaction.add_tags(:key1 => "value1")
      transaction.add_tags(:key2 => "value2")
      transaction._sample

      expect(transaction).to include_tags(
        "key1" => "value1",
        "key2" => "value2"
      )
    end
  end

  describe "#add_custom_data" do
    let(:transaction) { new_transaction }

    it "has a #add_custom_data alias" do
      expect(transaction.method(:add_custom_data)).to eq(transaction.method(:set_custom_data))
    end

    it "adds a custom Hash data to the transaction" do
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

      transaction._sample
      expect(transaction).to include_custom_data(
        "user" => {
          "id" => 123,
          "locale" => "abc"
        },
        "organization" => {
          "slug" => "appsignal",
          "plan" => "enterprise"
        }
      )
    end

    it "adds a custom Array data to the transaction" do
      transaction.add_custom_data([
        [123, "abc"],
        ["appsignal", "enterprise"]
      ])

      transaction._sample
      expect(transaction).to include_custom_data([
        [123, "abc"],
        ["appsignal", "enterprise"]
      ])
    end

    it "does not store non Hash or Array custom data" do
      logs =
        capture_logs do
          transaction.add_custom_data("abc")
          transaction._sample
          expect(transaction).to_not include_custom_data

          transaction.add_custom_data(123)
          transaction._sample
          expect(transaction).to_not include_custom_data

          transaction.add_custom_data(Object.new)
          transaction._sample
          expect(transaction).to_not include_custom_data
        end

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

    it "merges the custom data if called multiple times" do
      transaction.add_custom_data("abc" => "value")
      transaction.add_custom_data("def" => "value")

      transaction._sample
      expect(transaction).to include_custom_data(
        "abc" => "value",
        "def" => "value"
      )
    end
  end

  describe "#add_breadcrumb" do
    let(:transaction) { new_transaction }

    context "when over the limit" do
      before do
        22.times do |i|
          transaction.add_breadcrumb(
            "network",
            "GET http://localhost",
            "User made external network request",
            { :code => i + 1 },
            Time.parse("10-10-2010 10:00:00 UTC")
          )
        end
        transaction._sample
      end

      it "stores last <LIMIT> breadcrumbs on the transaction" do
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
    end

    context "with defaults" do
      it "stores breadcrumb with defaults on transaction" do
        timeframe_start = Time.now.utc.to_i
        transaction.add_breadcrumb("user_action", "clicked HOME")
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
    end

    context "with metadata argument that's not a Hash" do
      it "does not add the breadcrumb and logs and error" do
        logs =
          capture_logs do
            transaction.add_breadcrumb("category", "action", "message", "invalid metadata")
          end
        transaction._sample

        expect(transaction).to_not include_breadcrumbs
        expect(logs).to contains_log(
          :error,
          "add_breadcrumb: Cannot add breadcrumb. The given metadata argument is not a Hash."
        )
      end
    end
  end

  describe "#set_action" do
    let(:transaction) { new_transaction }

    context "when the action is set" do
      it "updates the action name on the transaction" do
        action_name = "PagesController#show"
        transaction.set_action(action_name)

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end
    end

    context "when the action is nil" do
      it "does not update the action name on the transaction" do
        action_name = "PagesController#show"
        transaction.set_action(action_name)
        transaction.set_action(nil)

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end
    end
  end

  describe "#set_action_if_nil" do
    let(:transaction) { new_transaction }

    context "when the action is not set" do
      it "updates the action name on the transaction" do
        expect(transaction.action).to eq(nil)
        expect(transaction).to_not have_action

        action_name = "PagesController#show"
        transaction.set_action_if_nil(action_name)

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end

      context "when the given action is nil" do
        it "does not update the action name on the transaction" do
          action_name = "something"
          transaction.set_action("something")
          transaction.set_action_if_nil(nil)

          expect(transaction.action).to eq(action_name)
          expect(transaction).to have_action(action_name)
        end
      end
    end

    context "when the action is set" do
      it "does not update the action name on the transaction" do
        action_name = "something"
        transaction.set_action("something")
        transaction.set_action_if_nil("something else")

        expect(transaction.action).to eq(action_name)
        expect(transaction).to have_action(action_name)
      end
    end
  end

  describe "#set_namespace" do
    let(:transaction) { new_transaction }

    context "when the namespace is not nil" do
      it "updates the namespace on the transaction" do
        namespace = "custom"
        transaction.set_namespace(namespace)

        expect(transaction.namespace).to eq namespace
        expect(transaction).to have_namespace(namespace)
      end
    end

    context "when the namespace is nil" do
      it "does not update the namespace on the transaction" do
        namespace = "custom"
        transaction.set_namespace(namespace)
        transaction.set_namespace(nil)

        expect(transaction.namespace).to eq(namespace)
        expect(transaction).to have_namespace(namespace)
      end
    end
  end

  describe "#set_queue_start" do
    let(:transaction) { new_transaction }

    it "sets the queue start in extension" do
      transaction.set_queue_start(10)

      expect(transaction).to have_queue_start(10)
    end

    it "does not set the queue start in extension when value is nil" do
      transaction.set_queue_start(nil)

      expect(transaction).to_not have_queue_start
    end

    it "does not raise an error when the queue start is too big" do
      expect(transaction.ext).to receive(:set_queue_start).and_raise(RangeError)

      expect(Appsignal.internal_logger).to receive(:warn).with("Queue start value 10 is too big")

      transaction.set_queue_start(10)
    end
  end

  describe "#set_metadata" do
    let(:transaction) { new_transaction }

    it "updates the metadata on the transaction" do
      transaction.set_metadata("request_method", "GET")

      expect(transaction).to include_metadata("request_method" => "GET")
    end

    context "when filter_metadata includes metadata key" do
      let(:options) { { :filter_metadata => ["filter_key"] } }

      it "does not set the metadata on the transaction" do
        transaction.set_metadata(:filter_key, "filtered value")
        transaction.set_metadata("filter_key", "filtered value")

        expect(transaction).to_not include_metadata("filter_key" => anything)
      end
    end

    context "when the key is nil" do
      it "does not update the metadata on the transaction" do
        transaction.set_metadata(nil, "GET")

        expect(transaction).to_not include_metadata
      end
    end

    context "when the value is nil" do
      it "does not update the metadata on the transaction" do
        transaction.set_metadata("request_method", nil)

        expect(transaction).to_not include_metadata
      end
    end
  end

  describe "storing sample data" do
    let(:transaction) { new_transaction }

    it "stores sample data on the transaction" do
      transaction.set_params(
        "string_param" => "string_value",
        :symbol_param => "symbol_value",
        "integer" => 123,
        "float" => 123.45,
        "array" => ["abc", 456, { "option" => true }],
        "hash" => { "hash_key" => "hash_value" }
      )

      transaction._sample
      expect(transaction).to include_params(
        "string_param" => "string_value",
        "symbol_param" => "symbol_value",
        "integer" => 123,
        "float" => 123.45,
        "array" => ["abc", 456, { "option" => true }],
        "hash" => { "hash_key" => "hash_value" }
      )
    end

    it "does not store non-Array and non-Hash data" do
      logs =
        capture_logs do
          transaction.set_params("some string")
          transaction._sample
          expect(transaction).to_not include_params

          transaction.set_params(123)
          transaction._sample
          expect(transaction).to_not include_params

          transaction.set_params(Class.new)
          transaction._sample
          expect(transaction).to_not include_params

          set = Set.new
          set.add("some value")
          transaction.set_params(set)
          transaction._sample
          expect(transaction).to_not include_params
        end

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
        %(Sample data 'params': Unsupported data type 'Set' received: #<Set: {"some value"}>)
      )
    end

    it "does not store data that can't be converted to JSON" do
      klass = Class.new do
        def initialize
          @calls = 0
        end

        def to_s
          raise "foo" if @calls > 0 # Cause a deliberate error

          @calls += 1
        end
      end

      transaction.set_params(klass.new => 1)
      logs = capture_logs { transaction._sample }

      expect(transaction).to_not include_params
      expect(logs).to contains_log :error,
        "Error generating data (RuntimeError: foo) for"
    end
  end

  describe "#set_sample_data" do
    let(:transaction) { new_transaction }

    it "updates the sample data on the transaction" do
      silence do
        transaction.send(
          :set_sample_data,
          "params",
          :controller => "blog_posts",
          :action     => "show",
          :id         => "1"
        )
      end

      expect(transaction).to include_params(
        "action" => "show",
        "controller" => "blog_posts",
        "id" => "1"
      )
    end

    context "when the data is no Array or Hash" do
      it "does not update the sample data on the transaction" do
        logs =
          capture_logs do
            silence { transaction.send(:set_sample_data, "params", "string") }
          end

        expect(transaction.to_h["sample_data"]).to eq({})
        expect(logs).to contains_log :error,
          %(Invalid sample data for 'params'. Value is not an Array or Hash: '"string"')
      end
    end

    context "when the data cannot be converted to JSON" do
      it "does not update the sample data on the transaction" do
        klass = Class.new do
          def to_s
            raise "foo" # Cause a deliberate error
          end
        end
        logs =
          capture_logs do
            silence { transaction.send(:set_sample_data, "params", klass.new => 1) }
          end

        expect(transaction).to_not include_params
        expect(logs).to contains_log :error,
          "Error generating data (RuntimeError: foo) for"
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
      before do
        stub_const("PG::UniqueViolation", Class.new(StandardError))
        transaction.add_error(error)
      end

      it "returns a sanizited error message" do
        expect(transaction).to have_error(
          "PG::UniqueViolation",
          "ERROR: duplicate key value violates unique constraint " \
            "\"index_users_on_email\" DETAIL: Key (email)=(?) already exists."
        )
      end
    end

    context "with a ActiveRecord::RecordNotUnique" do
      let(:error) do
        ActiveRecord::RecordNotUnique.new(
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
            "\"example_constraint\"\nDETAIL: Key (email)=(foo@example.com) already exists."
        )
      end
      before do
        stub_const("ActiveRecord::RecordNotUnique", Class.new(StandardError))
        transaction.add_error(error)
      end

      it "returns a sanizited error message" do
        expect(transaction).to have_error(
          "ActiveRecord::RecordNotUnique",
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
            "\"example_constraint\"\nDETAIL: Key (email)=(?) already exists."
        )
      end
    end

    context "with Rails module but without backtrace_cleaner method" do
      it "returns the backtrace uncleaned" do
        stub_const("Rails", Module.new)
        error = ExampleStandardError.new("error message")
        error.set_backtrace(["line 1", "line 2"])
        transaction.add_error(error)

        expect(last_transaction).to have_error(
          "ExampleStandardError",
          "error message",
          ["line 1", "line 2"]
        )
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

        it "cleans the backtrace with the Rails backtrace cleaner" do
          error = ExampleStandardError.new("error message")
          error.set_backtrace(["line 1", "line 2"])
          transaction.add_error(error)
          expect(last_transaction).to have_error(
            "ExampleStandardError",
            "error message",
            ["line 1", "line ?"]
          )
        end
      end
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
      it "should set an empty causes array as sample data" do
        transaction.send(:_set_error, error)

        expect(transaction).to include_error_causes([])
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

      it "sends the error causes information as sample data" do
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

      it "sends only the first causes as sample data" do
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

      it "sets an error on the transaction without an error message" do
        transaction.send(:_set_error, error)

        expect(transaction).to have_error(
          "ExampleStandardError",
          "",
          ["line 1"]
        )
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
      it "calls the given hook for each of the duplicate error transactions" do
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
      expect(transaction.ext).to receive(:start_event).with(0).and_call_original

      transaction.start_event
    end

    context "when transaction is paused" do
      it "does not start the event" do
        transaction.pause!
        expect(transaction.ext).to_not receive(:start_event)

        transaction.start_event
      end
    end
  end

  describe "#finish_event" do
    let(:transaction) { new_transaction }
    let(:fake_gc_time) { 0 }

    it "should finish the event in the extension" do
      expect(transaction.ext).to receive(:finish_event).with(
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
      expect(transaction.ext).to receive(:finish_event).with(
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
        expect(transaction.ext).to_not receive(:finish_event)

        transaction.start_event
      end
    end
  end

  describe "#record_event" do
    let(:transaction) { new_transaction }
    let(:fake_gc_time) { 0 }

    it "should record the event in the extension" do
      expect(transaction.ext).to receive(:record_event).with(
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
      expect(transaction.ext).to receive(:record_event).with(
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
        expect(transaction.ext).to_not receive(:record_event)

        transaction.record_event(
          "name",
          nil,
          nil,
          1000,
          nil
        )
      end
    end
  end

  describe "#instrument" do
    it_behaves_like "instrument helper" do
      let(:transaction) { new_transaction }
      let(:instrumenter) { transaction }
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
        expect(transaction.ext).to receive(:to_json).and_return("foo")
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
