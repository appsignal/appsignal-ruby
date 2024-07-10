describe Appsignal::Transaction do
  let(:transaction_id) { "1" }
  let(:time)           { Time.at(fixed_time) }
  let(:namespace)      { Appsignal::Transaction::HTTP_REQUEST }
  let(:env)            { {} }
  let(:merged_env)     { http_request_env_with_data(env) }
  let(:options)        { {} }
  let(:request)        { Rack::Request.new(merged_env) }
  let(:transaction)    { Appsignal::Transaction.new(transaction_id, namespace, request, options) }
  let(:log)            { StringIO.new }

  before { Timecop.freeze(time) }
  after { Timecop.return }
  around do |example|
    start_agent
    use_logger_with log do
      example.run
    end
  end

  describe "class methods" do
    def current_transaction
      Appsignal::Transaction.current
    end

    describe ".create" do
      def create_transaction(id = transaction_id)
        Appsignal::Transaction.create(id, namespace, request, options)
      end

      context "when no transaction is running" do
        let!(:transaction) { create_transaction }

        it "returns the created transaction" do
          expect(transaction).to be_a Appsignal::Transaction
          expect(transaction.transaction_id).to eq transaction_id
          expect(transaction.namespace).to eq namespace
          expect(transaction.request).to eq request

          expect(transaction).to have_id(transaction_id)
          expect(transaction).to have_namespace(namespace)
        end

        it "assigns the transaction to current" do
          expect(transaction).to eq current_transaction
        end
      end

      context "when a transaction is already running" do
        before { create_transaction }

        it "does not create a new transaction, but returns the current transaction" do
          expect do
            new_transaction = create_transaction("2")
            expect(new_transaction).to eq(current_transaction)
            expect(new_transaction.transaction_id).to eq(transaction_id)
          end.to_not(change { current_transaction })
        end

        it "logs a debug message" do
          create_transaction("2")
          expect(log_contents(log)).to contains_log :warn,
            "Trying to start new transaction with id '2', but a " \
              "transaction with id '#{transaction_id}' is already " \
              "running. Using transaction '#{transaction_id}'."
        end

        context "with option :force => true" do
          it "returns the newly created (and current) transaction" do
            original_transaction = current_transaction
            expect(original_transaction).to_not be_nil
            expect(current_transaction.transaction_id).to eq transaction_id

            options[:force] = true
            expect(create_transaction("2")).to_not eq original_transaction
            expect(current_transaction.transaction_id).to eq "2"
          end
        end
      end
    end

    describe ".current" do
      context "when there is a current transaction" do
        let!(:transaction) do
          Appsignal::Transaction.create(transaction_id, namespace, request, options)
        end

        it "reads :appsignal_transaction from the current Thread" do
          expect(current_transaction).to eq Thread.current[:appsignal_transaction]
          expect(current_transaction).to eq transaction
        end

        it "is not a NilTransaction" do
          expect(current_transaction.nil_transaction?).to eq false
          expect(current_transaction).to be_a Appsignal::Transaction
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
          expect(current_transaction.nil_transaction?).to eq true
          expect(current_transaction).to be_a Appsignal::Transaction::NilTransaction
        end

        it "returns false for current?" do
          expect(Appsignal::Transaction.current?).to be(false)
        end
      end
    end

    describe ".complete_current!" do
      let!(:transaction) { Appsignal::Transaction.create(transaction_id, namespace, options) }

      it "completes the current transaction" do
        expect(transaction).to eq current_transaction
        expect(transaction).to receive(:complete).and_call_original

        Appsignal::Transaction.complete_current!
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
          Appsignal::Transaction.complete_current!
          expect(log_contents(log)).to contains_log :error,
            "Failed to complete transaction ##{transaction.transaction_id}. ExampleStandardError"
        end

        it "clears the current transaction" do
          expect do
            Appsignal::Transaction.complete_current!
          end.to change { Thread.current[:appsignal_transaction] }.from(transaction).to(nil)
        end
      end
    end
  end

  describe "#complete" do
    context "when transaction is being sampled" do
      it "samples data" do
        transaction.set_tags(:foo => "bar")
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
        transaction.discard!
        transaction.complete

        expect(log_contents(log)).to contains_log :debug,
          "Skipping transaction '#{transaction_id}' because it was manually discarded."
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
  end

  context "pausing" do
    describe "#pause!" do
      it "changes the pause flag to true" do
        expect do
          transaction.pause!
        end.to change(transaction, :paused).from(false).to(true)
      end
    end

    describe "#resume!" do
      before { transaction.pause! }

      it "changes the pause flag to false" do
        expect do
          transaction.resume!
        end.to change(transaction, :paused).from(true).to(false)
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

  context "with transaction instance" do
    context "initialization" do
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

      it "sets the transaction id" do
        expect(transaction.transaction_id).to eq "1"
      end

      it "sets the namespace to http_request" do
        expect(transaction.namespace).to eq "http_request"
      end

      it "sets the request" do
        expect(transaction.request).to_not be_nil
      end

      it "sets the request not to paused" do
        expect(transaction.paused).to be_falsy
      end

      it "sets no tags by default" do
        expect(transaction.tags).to eq({})
      end

      describe "#options" do
        subject { transaction.options }

        it "sets the default :params_method" do
          expect(subject[:params_method]).to eq :params
        end

        context "with overridden options" do
          let(:options) { { :params_method => :filtered_params } }

          it "sets the overridden :params_method" do
            expect(subject[:params_method]).to eq :filtered_params
          end
        end
      end
    end

    describe "#store" do
      it "should return an empty store when it's not already present" do
        expect(transaction.store("test")).to eql({})
      end

      it "should store changes to the store" do
        transaction_store = transaction.store("test")
        transaction_store["transaction"] = "value"

        expect(transaction.store("test")).to eql("transaction" => "value")
      end
    end

    describe "#params" do
      subject { transaction.params }

      context "with custom params set on transaction" do
        before do
          transaction.set_params(:foo => "bar")
        end

        it "returns custom parameters" do
          expect(subject).to eq(:foo => "bar")
        end

        context "when params is a callable object" do
          it "calls the params object and sets the return value as parametesr" do
            transaction.set_params { { "param1" => "value1" } }

            expect(transaction.params).to eq(
              "param1" => "value1"
            )
          end
        end
      end

      context "without custom params set on transaction" do
        it "returns parameters from request" do
          expect(subject).to eq(
            "action" => "show",
            "controller" => "blog_posts",
            "id" => "1"
          )
        end
      end
    end

    describe "#params=" do
      around { |example| keep_transactions { example.run } }

      it "sets params on the transaction" do
        params = { "foo" => "bar" }
        silence { transaction.params = params }

        transaction._sample
        expect(transaction.params).to eq(params)
        expect(transaction).to include_params(params)
      end

      it "logs a deprecation warning" do
        transaction.params = { "foo" => "bar" }

        expect(log_contents(log)).to contains_log(
          :warn,
          "Transaction#params= is deprecated." \
            "Use Transaction#set_params or #set_params_if_nil instead."
        )
      end
    end

    describe "#set_params" do
      around { |example| keep_transactions { example.run } }

      context "when the params are set" do
        it "updates the params on the transaction" do
          params = { "key" => "value" }
          transaction.set_params(params)

          transaction._sample
          expect(transaction.params).to eq(params)
          expect(transaction).to include_params(params)
        end

        it "updates the params on the transaction with a block" do
          params = { "key" => "value" }
          transaction.set_params { params }

          transaction._sample
          expect(transaction.params).to eq(params)
          expect(transaction).to include_params(params)
        end

        it "updates with the params argument when both an argument and block are given" do
          arg_params = { "argument" => "value" }
          block_params = { "block" => "value" }
          transaction.set_params(arg_params) { block_params }

          transaction._sample
          expect(transaction.params).to eq(arg_params)
          expect(transaction).to include_params(arg_params)
        end
      end

      context "when the given params is nil" do
        it "does not update the params on the transaction" do
          params = { "key" => "value" }
          transaction.set_params(params)
          transaction.set_params(nil)

          transaction._sample
          expect(transaction.params).to eq(params)
          expect(transaction).to include_params(params)
        end
      end
    end

    describe "#set_params_if_nil" do
      around { |example| keep_transactions { example.run } }

      context "when the params are not set" do
        it "sets the params on the transaction" do
          params = { "key" => "value" }
          transaction.set_params_if_nil(params)

          transaction._sample
          expect(transaction.params).to eq(params)
          expect(transaction).to include_params(params)
        end

        it "updates the params on the transaction with a block" do
          params = { "key" => "value" }
          transaction.set_params_if_nil { params }

          transaction._sample
          expect(transaction.params).to eq(params)
          expect(transaction).to include_params(params)
        end

        it "updates with the params argument when both an argument and block are given" do
          arg_params = { "argument" => "value" }
          block_params = { "block" => "value" }
          transaction.set_params_if_nil(arg_params) { block_params }

          transaction._sample
          expect(transaction.params).to eq(arg_params)
          expect(transaction).to include_params(arg_params)
        end

        context "when the given params is nil" do
          it "does not update the params on the transaction" do
            params = { "key" => "value" }
            transaction.set_params(params)
            transaction.set_params_if_nil(nil)

            transaction._sample
            expect(transaction.params).to eq(params)
            expect(transaction).to include_params(params)
          end
        end
      end

      context "when the params are set" do
        it "does not update the params on the transaction" do
          preset_params = { "other" => "params" }
          params = { "key" => "value" }
          transaction.set_params(preset_params)
          transaction.set_params_if_nil(params)

          transaction._sample
          expect(transaction.params).to eq(preset_params)
          expect(transaction).to include_params(preset_params)
        end

        it "does not update the params with a block on the transaction" do
          preset_params = { "other" => "params" }
          params = { "key" => "value" }
          transaction.set_params(preset_params)
          transaction.set_params_if_nil { params }

          transaction._sample
          expect(transaction.params).to eq(preset_params)
          expect(transaction).to include_params(preset_params)
        end
      end
    end

    describe "#set_session_data" do
      around { |example| keep_transactions { example.run } }

      context "when the session data is set" do
        it "updates the session data on the transaction" do
          data = { "key" => "value" }
          transaction.set_session_data(data)

          transaction._sample
          expect(transaction).to include_session_data(data)
        end

        it "updates the session data on the transaction with a block" do
          data = { "key" => "value" }
          transaction.set_session_data { data }

          transaction._sample
          expect(transaction).to include_session_data(data)
        end

        it "updates with the session data argument when both an argument and block are given" do
          arg_data = { "argument" => "value" }
          block_data = { "block" => "value" }
          transaction.set_session_data(arg_data) { block_data }

          transaction._sample
          expect(transaction).to include_session_data(arg_data)
        end

        it "does not include filtered out session data" do
          Appsignal.config[:filter_session_data] = ["filtered_key"]
          transaction.set_session_data("data" => "value1", "filtered_key" => "filtered_value")

          transaction._sample
          expect(transaction).to include_session_data("data" => "value1")
        end
      end

      context "when the given session data is nil" do
        it "does not update the session data on the transaction" do
          data = { "key" => "value" }
          transaction.set_session_data(data)
          transaction.set_session_data(nil)

          transaction._sample
          expect(transaction).to include_session_data(data)
        end
      end
    end

    describe "#set_session_data_if_nil" do
      around { |example| keep_transactions { example.run } }

      context "when the params are not set" do
        it "sets the params on the transaction" do
          data = { "key" => "value" }
          transaction.set_session_data_if_nil(data)

          transaction._sample
          expect(transaction).to include_session_data(data)
        end

        it "updates the params on the transaction with a block" do
          data = { "key" => "value" }
          transaction.set_session_data_if_nil { data }

          transaction._sample
          expect(transaction).to include_session_data(data)
        end

        it "updates with the params argument when both an argument and block are given" do
          arg_data = { "argument" => "value" }
          block_data = { "block" => "value" }
          transaction.set_session_data_if_nil(arg_data) { block_data }

          transaction._sample
          expect(transaction).to include_session_data(arg_data)
        end

        context "when the given params is nil" do
          it "does not update the params on the transaction" do
            data = { "key" => "value" }
            transaction.set_session_data(data)
            transaction.set_session_data_if_nil(nil)

            transaction._sample
            expect(transaction).to include_session_data(data)
          end
        end
      end

      context "when the params are set" do
        it "does not update the params on the transaction" do
          preset_data = { "other" => "data" }
          data = { "key" => "value" }
          transaction.set_session_data(preset_data)
          transaction.set_session_data_if_nil(data)

          transaction._sample
          expect(transaction).to include_session_data(preset_data)
        end

        it "does not update the params with a block on the transaction" do
          preset_data = { "other" => "data" }
          data = { "key" => "value" }
          transaction.set_session_data(preset_data)
          transaction.set_session_data_if_nil { data }

          transaction._sample
          expect(transaction).to include_session_data(preset_data)
        end
      end
    end

    describe "#set_headers" do
      around { |example| keep_transactions { example.run } }

      context "when the headers are set" do
        it "updates the headers on the transaction" do
          headers = { "PATH_INFO" => "value" }
          transaction.set_headers(headers)

          transaction._sample
          expect(transaction).to include_environment(headers)
        end

        it "updates the session data on the transaction with a block" do
          headers = { "PATH_INFO" => "value" }
          transaction.set_headers { headers }

          transaction._sample
          expect(transaction).to include_environment(headers)
        end

        it "updates with the session data argument when both an argument and block are given" do
          arg_data = { "PATH_INFO" => "/arg-path" }
          block_data = { "PATH_INFO" => "/block-path" }
          transaction.set_headers(arg_data) { block_data }

          transaction._sample
          expect(transaction).to include_environment(arg_data)
        end

        it "does not include filtered out session data" do
          Appsignal.config[:request_headers] = ["MY_HEADER"]
          transaction.set_headers("MY_HEADER" => "value1", "filtered_key" => "filtered_value")

          transaction._sample
          expect(transaction).to include_environment("MY_HEADER" => "value1")
        end
      end

      context "when the given session data is nil" do
        it "does not update the session data on the transaction" do
          headers = { "PATH_INFO" => "value" }
          transaction.set_headers(headers)
          transaction.set_headers(nil)

          transaction._sample
          expect(transaction).to include_environment(headers)
        end
      end
    end

    describe "#set_headers_if_nil" do
      around { |example| keep_transactions { example.run } }

      context "when the params are not set" do
        it "sets the params on the transaction" do
          headers = { "PATH_INFO" => "value" }
          transaction.set_headers_if_nil(headers)

          transaction._sample
          expect(transaction).to include_environment(headers)
        end

        it "updates the params on the transaction with a block" do
          headers = { "PATH_INFO" => "value" }
          transaction.set_headers_if_nil { headers }

          transaction._sample
          expect(transaction).to include_environment(headers)
        end

        it "updates with the params argument when both an argument and block are given" do
          arg_data = { "PATH_INFO" => "/arg-path" }
          block_data = { "PATH_INFO" => "/block-path" }
          transaction.set_headers_if_nil(arg_data) { block_data }

          transaction._sample
          expect(transaction).to include_environment(arg_data)
        end

        context "when the given params is nil" do
          it "does not update the params on the transaction" do
            headers = { "PATH_INFO" => "value" }
            transaction.set_headers(headers)
            transaction.set_headers_if_nil(nil)

            transaction._sample
            expect(transaction).to include_environment(headers)
          end
        end
      end

      context "when the params are set" do
        it "does not update the params on the transaction" do
          preset_headers = { "PATH_INFO" => "/first-path" }
          headers = { "PATH_INFO" => "/other-path" }
          transaction.set_headers(preset_headers)
          transaction.set_headers_if_nil(headers)

          transaction._sample
          expect(transaction).to include_environment(preset_headers)
        end

        it "does not update the params with a block on the transaction" do
          preset_headers = { "PATH_INFO" => "/first-path" }
          headers = { "PATH_INFO" => "/other-path" }
          transaction.set_headers(preset_headers)
          transaction.set_headers_if_nil { headers }

          transaction._sample
          expect(transaction).to include_environment(preset_headers)
        end
      end
    end

    describe "#set_tags" do
      let(:long_string) { "a" * 10_001 }

      it "stores tags on the transaction" do
        transaction.set_tags(
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
        transaction.set_tags(:key1 => "value1")
        transaction.set_tags(:key2 => "value2")
        transaction._sample

        expect(transaction).to include_tags(
          "key1" => "value1",
          "key2" => "value2"
        )
      end
    end

    describe "#set_custom_data" do
      let(:log_stream) { std_stream }
      let(:logs) { log_contents(log_stream) }
      around { |example| use_logger_with(log_stream) { example.run } }

      it "stores custom Hash data on the transaction" do
        transaction.set_custom_data(
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

      it "stores custom Array data on the transaction" do
        transaction.set_custom_data([
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
        transaction.set_custom_data("abc")
        transaction._sample
        expect(transaction).to_not include_custom_data

        transaction.set_custom_data(123)
        transaction._sample
        expect(transaction).to_not include_custom_data

        transaction.set_custom_data(Object.new)
        transaction._sample
        expect(transaction).to_not include_custom_data

        expect(logs).to contains_log(
          :error,
          "set_custom_data: Unsupported data type String received."
        )
        expect(logs).to contains_log(
          :error,
          "set_custom_data: Unsupported data type Integer received."
        )
        expect(logs).to contains_log(
          :error,
          "set_custom_data: Unsupported data type String received."
        )
      end

      it "overwrites the custom data if called multiple times" do
        transaction.set_custom_data("user" => { "id" => 123 })
        transaction.set_custom_data("user" => { "id" => 456 })

        transaction._sample
        expect(transaction).to include_custom_data("user" => { "id" => 456 })
      end
    end

    describe "#add_breadcrumb" do
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
          transaction.add_breadcrumb("category", "action", "message", "invalid metadata")
          transaction._sample

          expect(transaction).to_not include_breadcrumbs
          expect(log_contents(log)).to contains_log(
            :error,
            "add_breadcrumb: Cannot add breadcrumb. The given metadata argument is not a Hash."
          )
        end
      end
    end

    describe "#set_action" do
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

    describe "#set_http_or_background_action" do
      context "for a hash with controller and action" do
        it "sets the action" do
          transaction.set_http_or_background_action(
            :controller => "HomeController",
            :action => "show"
          )
          expect(transaction).to have_action("HomeController#show")
        end
      end

      context "for a hash with just action" do
        it "sets the action" do
          transaction.set_http_or_background_action(:action => "show")
          expect(transaction).to have_action("show")
        end
      end

      context "for a hash with class and method" do
        it "sets the action" do
          transaction.set_http_or_background_action(:class => "Worker", :method => "perform")
          expect(transaction).to have_action("Worker#perform")
        end
      end

      context "when action is already set" do
        it "does not overwrite the set action" do
          transaction.set_action("MyCustomAction#perform")
          transaction.set_http_or_background_action(:class => "Worker", :method => "perform")
          expect(transaction).to have_action("MyCustomAction#perform")
        end
      end
    end

    describe "#set_queue_start" do
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

    describe "#set_http_or_background_queue_start" do
      let(:err_stream) { std_stream }
      let(:stderr) { err_stream.read }
      let(:header_factor) { 1_000 }
      let(:env_queue_start) { fixed_time + 20 } # in seconds

      def set_http_or_background_queue_start
        capture_std_streams(std_stream, err_stream) do
          transaction.set_http_or_background_queue_start
        end
      end

      context "when a queue time is found in a request header" do
        let(:header_time) { ((fixed_time + 10) * header_factor).to_i } # in milliseconds
        let(:env) { { "HTTP_X_REQUEST_START" => "t=#{header_time}" } }

        it "sets the http header value in milliseconds on the transaction" do
          set_http_or_background_queue_start

          expect(transaction).to have_queue_start(1_389_783_610_000)
        end

        it "logs a deprecation message" do
          logs = capture_logs { set_http_or_background_queue_start }

          expect(logs).to contains_log(
            :warn,
            "The Appsignal::Transaction#set_http_or_background_queue_start " \
              "method has been deprecated."
          )
        end

        it "prints a deprecation message" do
          set_http_or_background_queue_start

          expect(stderr).to include(
            "The Appsignal::Transaction#set_http_or_background_queue_start " \
              "method has been deprecated."
          )
        end

        context "when a :queue_start key is found in the transaction environment" do
          let(:env) do
            {
              "HTTP_X_REQUEST_START" => "t=#{header_time}",
              :queue_start => env_queue_start
            }
          end

          it "sets the http header value in milliseconds on the transaction" do
            transaction.set_http_or_background_queue_start

            expect(transaction).to have_queue_start(1_389_783_610_000)
          end
        end
      end

      context "when a :queue_start key is found in the transaction environment" do
        let(:env) { { :queue_start => env_queue_start } } # in seconds

        it "sets the :queue_start value in milliseconds on the transaction" do
          transaction.set_http_or_background_queue_start

          expect(transaction).to have_queue_start(1_389_783_620_000)
        end
      end
    end

    describe "#set_metadata" do
      it "updates the metadata on the transaction" do
        transaction.set_metadata("request_method", "GET")

        expect(transaction).to include_metadata("request_method" => "GET")
      end

      context "when filter_metadata includes metadata key" do
        before { Appsignal.config[:filter_metadata] = ["filter_key"] }
        after { Appsignal.config[:filter_metadata] = [] }

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
      let(:transaction) { http_request_transaction }

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

        logs = log_contents(log)
        expect(logs).to contains_log :error,
          %(Invalid sample data for 'params'. Value is not an Array or Hash: '"some string"')
        expect(logs).to contains_log :error,
          %(Invalid sample data for 'params'. Value is not an Array or Hash: '123')
        expect(logs).to contains_log :error,
          %(Invalid sample data for 'params'. Value is not an Array or Hash: '"#<Class>"')
        expect(logs).to contains_log :error,
          %(Invalid sample data for 'params'. Value is not an Array or Hash: '"#<Set>"')
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
        transaction._sample

        expect(transaction).to_not include_params
        expect(log_contents(log)).to contains_log :error,
          "Error generating data (RuntimeError: foo) for"
      end
    end

    describe "#set_sample_data" do
      it "updates the sample data on the transaction" do
        silence do
          transaction.set_sample_data(
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
          silence { transaction.set_sample_data("params", "string") }

          expect(transaction.to_h["sample_data"]).to eq({})
          expect(log_contents(log)).to contains_log :error,
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
          silence { transaction.set_sample_data("params", klass.new => 1) }

          expect(transaction).to_not include_params
          expect(log_contents(log)).to contains_log :error,
            "Error generating data (RuntimeError: foo) for"
        end
      end
    end

    describe "#sample_data" do
      let(:env) { { "rack.session" => { "session" => "value" } } }

      it "sets sample data" do
        transaction.set_tags "tag" => "value"
        transaction.add_breadcrumb "category", "action", "message", "key" => "value"
        silence { transaction.sample_data }

        expect(transaction).to include_environment(
          "REQUEST_METHOD" => "GET",
          "SERVER_NAME" => "example.org",
          "SERVER_PORT" => "80",
          "PATH_INFO" => "/blog"
        )
        expect(transaction).to include_session_data("session" => "value")
        expect(transaction).to include_params(
          "controller" => "blog_posts",
          "action" => "show",
          "id" => "1"
        )
        expect(transaction).to include_sample_metadata("key" => "value")
        expect(transaction).to include_tags("tag" => "value")
        expect(transaction).to include_breadcrumb(
          "action",
          "category",
          "message",
          { "key" => "value" },
          kind_of(Integer)
        )
      end

      context "when params is a callable object" do
        it "calls the params object and sets the return value as parametesr" do
          transaction.set_params { { "param1" => "value1" } }

          silence { transaction.sample_data }
          expect(transaction).to include_params(
            "param1" => "value1"
          )
        end
      end
    end

    describe "#set_error" do
      let(:env) { http_request_env_with_data }
      let(:error) do
        e = ExampleStandardError.new("test message")
        allow(e).to receive(:backtrace).and_return(["line 1"])
        e
      end

      it "should also respond to add_exception for backwards compatibility" do
        expect(transaction).to respond_to(:add_exception)
      end

      it "should not add the error if appsignal is not active" do
        allow(Appsignal).to receive(:active?).and_return(false)
        expect(transaction.ext).to_not receive(:set_error)

        transaction.set_error(error)
      end

      context "when error is not an error" do
        let(:error) { Object.new }

        it "does not add the error" do
          expect(Appsignal.internal_logger).to receive(:error).with(
            "Appsignal::Transaction#set_error: Cannot set error. " \
              "The given value is not an exception: #{error.inspect}"
          )
          expect(transaction.ext).to_not receive(:set_error)

          transaction.set_error(error)
        end
      end

      context "for a http request" do
        it "should set an error in the extension" do
          expect(transaction.ext).to receive(:set_error).with(
            "ExampleStandardError",
            "test message",
            Appsignal::Utils::Data.generate(["line 1"])
          )

          transaction.set_error(error)
        end
      end

      context "when the error has no causes" do
        it "should not send the causes information as sample data" do
          expect(transaction.ext).to_not receive(:set_sample_data)

          transaction.set_error(error)
        end
      end

      context "when the error has multiple causes" do
        let(:error) do
          e = ExampleStandardError.new("test message")
          e2 = RuntimeError.new("cause message")
          e3 = StandardError.new("cause message 2")
          allow(e).to receive(:backtrace).and_return(["line 1"])
          allow(e).to receive(:cause).and_return(e2)
          allow(e2).to receive(:cause).and_return(e3)
          e
        end

        it "sends the causes information as sample data" do
          expect(transaction.ext).to receive(:set_error).with(
            "ExampleStandardError",
            "test message",
            Appsignal::Utils::Data.generate(["line 1"])
          )

          expect(transaction.ext).to receive(:set_sample_data).with(
            "error_causes",
            Appsignal::Utils::Data.generate(
              [
                {
                  :name => "RuntimeError",
                  :message => "cause message"
                },
                {
                  :name => "StandardError",
                  :message => "cause message 2"
                }
              ]
            )
          )

          expect(Appsignal.internal_logger).to_not receive(:debug)

          transaction.set_error(error)
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

          allow(e).to receive(:backtrace).and_return(["line 1"])
          e
        end

        it "sends only the first causes as sample data" do
          expect(transaction.ext).to receive(:set_error).with(
            "ExampleStandardError",
            "wrapper error 10",
            Appsignal::Utils::Data.generate(["line 1"])
          )

          expected_error_causes = Array.new(10) do |i|
            {
              :name => "ExampleStandardError",
              :message => "wrapper error #{9 - i}"
            }
          end

          expected_error_causes.last[:is_root_cause] = false

          expect(transaction.ext).to receive(:set_sample_data).with(
            "error_causes",
            Appsignal::Utils::Data.generate(expected_error_causes)
          )

          expect(Appsignal.internal_logger).to receive(:debug).with(
            "Appsignal::Transaction#set_error: Error has more " \
              "than 10 error causes. Only the first 10 " \
              "will be reported."
          )

          transaction.set_error(error)
        end
      end

      context "when error message is nil" do
        let(:error) do
          e = ExampleStandardError.new
          allow(e).to receive(:message).and_return(nil)
          allow(e).to receive(:backtrace).and_return(["line 1"])
          e
        end

        it "should not raise an error" do
          transaction.set_error(error)
        end

        it "should set an error in the extension" do
          expect(transaction.ext).to receive(:set_error).with(
            "ExampleStandardError",
            "",
            Appsignal::Utils::Data.generate(["line 1"])
          )

          transaction.set_error(error)
        end
      end
    end

    describe "#start_event" do
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
        let(:instrumenter) { transaction }
      end
    end

    context "generic request" do
      let(:env) { {} }
      subject { Appsignal::Transaction::GenericRequest.new(env) }

      it "initializes with an empty env" do
        expect(subject.env).to be_empty
      end

      context "when given an env" do
        let(:env) do
          {
            :params => { :id => 1 },
            :queue_start => 10
          }
        end

        it "sets the given env" do
          expect(subject.env).to eq env
        end

        it "sets the params present in the env" do
          expect(subject.params).to eq(:id => 1)
        end
      end
    end

    # private

    describe "#background_queue_start" do
      subject { transaction.send(:background_queue_start) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to eq nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to eq nil }
      end

      context "when queue start is nil" do
        it { is_expected.to eq nil }
      end

      context "when queue start is set" do
        let(:env) { background_env_with_data }

        it { is_expected.to eq 1_389_783_600_000 }
      end
    end

    describe "#http_queue_start" do
      let(:slightly_earlier_time) { fixed_time - 0.4 }
      let(:slightly_earlier_time_value) { (slightly_earlier_time * factor).to_i }
      subject { transaction.send(:http_queue_start) }

      shared_examples "http queue start" do
        context "when request is nil" do
          let(:request) { nil }

          it { is_expected.to be_nil }
        end

        context "when env is nil" do
          before { expect(transaction.request).to receive(:env).and_return(nil) }

          it { is_expected.to be_nil }
        end

        context "with no relevant header set" do
          let(:env) { {} }

          it { is_expected.to be_nil }
        end

        context "with the HTTP_X_REQUEST_START header set" do
          let(:env) { { "HTTP_X_REQUEST_START" => "t=#{slightly_earlier_time_value}" } }

          it { is_expected.to eq 1_389_783_599_600 }

          context "with unparsable content" do
            let(:env) { { "HTTP_X_REQUEST_START" => "something" } }

            it { is_expected.to be_nil }
          end

          context "with unparsable content at the end" do
            let(:env) { { "HTTP_X_REQUEST_START" => "t=#{slightly_earlier_time_value}aaaa" } }

            it { is_expected.to eq 1_389_783_599_600 }
          end

          context "with a really low number" do
            let(:env) { { "HTTP_X_REQUEST_START" => "t=100" } }

            it { is_expected.to be_nil }
          end

          context "with the alternate HTTP_X_QUEUE_START header set" do
            let(:env) { { "HTTP_X_QUEUE_START" => "t=#{slightly_earlier_time_value}" } }

            it { is_expected.to eq 1_389_783_599_600 }
          end
        end
      end

      context "time in milliseconds" do
        let(:factor) { 1_000 }

        it_should_behave_like "http queue start"
      end

      context "time in microseconds" do
        let(:factor) { 1_000_000 }

        it_should_behave_like "http queue start"
      end
    end

    describe "#sanitized_params" do
      subject { transaction.send(:sanitized_params) }

      context "with custom params" do
        before do
          transaction.set_params(:foo => "bar", :baz => :bat)
        end

        it "returns custom params" do
          is_expected.to eq(:foo => "bar", :baz => :bat)
        end

        context "with AppSignal filtering" do
          before { Appsignal.config.config_hash[:filter_parameters] = %w[foo] }
          after { Appsignal.config.config_hash[:filter_parameters] = [] }

          it "returns sanitized custom params" do
            expect(subject).to eq(:foo => "[FILTERED]", :baz => :bat)
          end
        end
      end

      context "without request params" do
        before { allow(transaction.request).to receive(:params).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when request params crashes" do
        before { allow(transaction.request).to receive(:params).and_raise(NoMethodError) }

        it { is_expected.to be_nil }
      end

      context "when request params method does not exist" do
        let(:options) { { :params_method => :nonsense } }

        it { is_expected.to be_nil }
      end

      context "when not sending params" do
        before { Appsignal.config.config_hash[:send_params] = false }
        after { Appsignal.config.config_hash[:send_params] = true }

        it { is_expected.to be_nil }
      end

      context "with an array" do
        let(:request) do
          Appsignal::Transaction::GenericRequest.new(
            background_env_with_data(:params => %w[arg1 arg2])
          )
        end

        it { is_expected.to eq %w[arg1 arg2] }

        context "with AppSignal filtering" do
          before { Appsignal.config.config_hash[:filter_parameters] = %w[foo] }
          after { Appsignal.config.config_hash[:filter_parameters] = [] }

          it { is_expected.to eq %w[arg1 arg2] }
        end
      end

      context "with env" do
        context "with sanitization" do
          let(:request) do
            Appsignal::Transaction::GenericRequest.new(
              http_request_env_with_data(:params => { :foo => :bar })
            )
          end

          it "should call the params sanitizer" do
            expect(subject).to eq(:foo => :bar)
          end
        end

        context "with AppSignal filtering" do
          let(:request) do
            Appsignal::Transaction::GenericRequest.new(
              http_request_env_with_data(:params => { :foo => :bar, :baz => :bat })
            )
          end
          before { Appsignal.config.config_hash[:filter_parameters] = %w[foo] }
          after { Appsignal.config.config_hash[:filter_parameters] = [] }

          it "should call the params sanitizer with filtering" do
            expect(subject).to eq(:foo => "[FILTERED]", :baz => :bat)
          end
        end
      end
    end

    describe "#sanitized_environment" do
      let(:allowlisted_keys) { Appsignal.config[:request_headers] }
      subject { transaction.send(:sanitized_environment) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when env is present" do
        let(:env) do
          {}.tap do |hash|
            allowlisted_keys.each { |o| hash[o] = 1 } # use all allowlisted keys
            hash[allowlisted_keys] = nil # don't add if nil
            hash[:not_allowlisted] = "I will be sanitized"
          end
        end

        it "only sets allowlisted keys" do
          expect(subject.keys).to match_array(allowlisted_keys)
        end

        context "with configured request_headers" do
          before do
            Appsignal.config.config_hash[:request_headers] = %w[CONTENT_LENGTH]
          end

          it "only sets allowlisted keys" do
            expect(subject.keys).to match_array(%w[CONTENT_LENGTH])
          end
        end
      end
    end

    describe "#sanitized_session_data" do
      subject { transaction.send(:sanitized_session_data) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when session is nil" do
        before { expect(transaction.request).to receive(:session).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when session is empty" do
        before { expect(transaction.request).to receive(:session).and_return({}) }

        it { is_expected.to eq({}) }
      end

      context "when request class does not have a session method" do
        let(:request) { Appsignal::Transaction::GenericRequest.new({}) }

        it { is_expected.to be_nil }
      end

      context "with a session" do
        let(:session_data_filter) { [] }
        before { Appsignal.config[:filter_session_data] = session_data_filter }
        after { Appsignal.config[:filter_session_data] = [] }

        context "with generic session object" do
          before do
            expect(transaction).to respond_to(:request)
            allow(transaction).to receive_message_chain(
              :request,
              :session => { :foo => :bar, :abc => :def }
            )
            allow(transaction).to receive_message_chain(:request, :fullpath => :bar)
          end

          context "without session filtering" do
            it "keeps the session data intact" do
              expect(subject).to eq(:foo => :bar, :abc => :def)
            end
          end

          context "with session filtering" do
            let(:session_data_filter) { %w[foo] }

            it "filters the session data" do
              expect(subject).to eq(:foo => "[FILTERED]", :abc => :def)
            end
          end
        end

        if defined? ActionDispatch::Request::Session
          context "with ActionDispatch::Request::Session" do
            let(:action_dispatch_session) do
              store = Class.new do
                def load_session(_env)
                  [1, { :foo => :bar, :abc => :def }]
                end

                def session_exists?(_env)
                  true
                end
              end.new
              ActionDispatch::Request::Session.create(store,
                ActionDispatch::Request.new("rack.input" => StringIO.new), {})
            end
            before do
              expect(transaction).to respond_to(:request)
              allow(transaction).to receive_message_chain(
                :request,
                :session => action_dispatch_session
              )
              allow(transaction).to receive_message_chain(:request, :fullpath => :bar)
            end

            context "without session filtering" do
              it "keeps the session data intact" do
                expect(subject).to eq("foo" => :bar, "abc" => :def)
              end
            end

            context "with session filtering" do
              let(:session_data_filter) { %w[foo] }

              it "filters the session data" do
                expect(subject).to eq("foo" => "[FILTERED]", "abc" => :def)
              end
            end
          end
        end

        context "when not sending session data" do
          before { Appsignal.config[:send_session_data] = false }

          it "does not set any session data on the transaction" do
            expect(subject).to be_nil
          end
        end
      end
    end

    describe "#sanitized_metadata" do
      subject { transaction.send(:sanitized_metadata) }

      context "when request is nil" do
        let(:request) { nil }

        it { is_expected.to be_nil }
      end

      context "when env is nil" do
        before { expect(transaction.request).to receive(:env).and_return(nil) }

        it { is_expected.to be_nil }
      end

      context "when env is present" do
        let(:env) { { "key" => "value" } }

        it { is_expected.to eq("key" => "value") }

        context "with filter_metadata option set" do
          before { Appsignal.config[:filter_metadata] = ["key"] }
          after { Appsignal.config[:filter_metadata] = [] }

          it "filters out keys listed in the filter_metadata option" do
            expect(subject.keys).to_not include("key")
          end
        end
      end
    end

    describe "#cleaned_backtrace" do
      subject { transaction.send(:cleaned_backtrace, ["line 1", "line 2"]) }

      it "returns the backtrace" do
        expect(subject).to eq ["line 1", "line 2"]
      end

      context "with Rails module but without backtrace_cleaner method" do
        it "returns the backtrace uncleaned" do
          stub_const("Rails", Module.new)
          expect(subject).to eq ["line 1", "line 2"]
        end
      end

      if rails_present?
        context "with rails" do
          it "cleans the backtrace with the Rails backtrace cleaner" do
            ::Rails.backtrace_cleaner.add_filter do |line|
              line.tr("2", "?")
            end
            expect(subject).to eq ["line 1", "line ?"]
          end
        end
      end
    end
  end

  describe "#cleaned_error_message" do
    let(:error) { StandardError.new("Error message") }
    subject { transaction.send(:cleaned_error_message, error) }

    it "returns the error message" do
      expect(subject).to eq "Error message"
    end

    context "with a PG::UniqueViolation" do
      before do
        stub_const("PG::UniqueViolation", Class.new(StandardError))
      end

      let(:error) do
        PG::UniqueViolation.new(
          "ERROR: duplicate key value violates unique constraint " \
            "\"index_users_on_email\" DETAIL: Key (email)=(test@test.com) already exists."
        )
      end

      it "returns a sanizited error message" do
        expect(subject).to eq "ERROR: duplicate key value violates unique constraint " \
          "\"index_users_on_email\" DETAIL: Key (email)=(?) already exists."
      end
    end

    context "with a ActiveRecord::RecordNotUnique" do
      before do
        stub_const("ActiveRecord::RecordNotUnique", Class.new(StandardError))
      end

      let(:error) do
        ActiveRecord::RecordNotUnique.new(
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
            "\"example_constraint\"\nDETAIL: Key (email)=(foo@example.com) already exists."
        )
      end

      it "returns a sanizited error message" do
        expect(subject).to eq \
          "PG::UniqueViolation: ERROR: duplicate key value violates unique constraint " \
            "\"example_constraint\"\nDETAIL: Key (email)=(?) already exists."
      end
    end
  end

  describe ".to_hash / .to_h" do
    subject { transaction.to_hash }

    context "when extension returns serialized JSON" do
      it "parses the result and returns a Hash" do
        expect(subject).to include(
          "action" => nil,
          "error" => nil,
          "events" => [],
          "id" => transaction_id,
          "metadata" => {},
          "namespace" => namespace,
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

    it "should have method stubs" do
      subject.complete
      subject.pause!
      subject.resume!
      subject.paused?
      subject.store(:key)
      subject.set_tags(:tag => 1)
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
