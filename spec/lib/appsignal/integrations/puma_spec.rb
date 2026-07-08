# frozen_string_literal: true

require "appsignal/integrations/puma"

describe Appsignal::Integrations::PumaServer do
  describe "#lowlevel_error" do
    before do
      stub_const("Puma", PumaMock)
      stub_const("Puma::Server", puma_server)
      Appsignal::Hooks::PumaHook.new.install
    end

    let(:puma_server) { default_puma_server_mock }
    let(:queue_start_time) { fixed_time * 1_000 }
    let(:env) do
      Rack::MockRequest.env_for(
        "/some/path",
        "REQUEST_METHOD" => "GET",
        :params => { "page" => 2, "query" => "lorem" },
        "rack.session" => { "session" => "data", "user_id" => 123 },
        "HTTP_X_REQUEST_START" => "t=#{queue_start_time.to_i}" # in milliseconds
      )
    end
    let(:server) { Puma::Server.new }
    let(:error) { ExampleException.new("error message") }
    around { |example| keep_transactions { example.run } }

    def lowlevel_error(error, env, status = nil)
      result =
        if status
          server.lowlevel_error(error, env, status)
        else
          server.lowlevel_error(error, env)
        end
      # Transaction is normally closed by the EventHandler's RACK_AFTER_REPLY hook
      last_transaction&.complete
      result
    end

    describe "reporting an error on the active transaction" do
      def perform
        lowlevel_error(error, env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        create_transaction
        expect do
          perform
        end.to_not(change { created_transactions.count })

        expect(last_transaction).to have_error("ExampleException", "error message")
        expect(last_transaction).to include_tags("reported_by" => "puma_lowlevel_error")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        create_transaction
        expect do
          perform
        end.to_not(change { created_transactions.count })

        event = root_span.events.find { |e| e.name == "exception" }
        expect(event).not_to be_nil
        expect(event.attributes["exception.type"]).to eq("ExampleException")
        expect(event.attributes["exception.message"]).to eq("error message")
        expect(event.attributes["exception.stacktrace"]).to be_a(String)
        expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
        expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        expect(root_span.kind).to eq(:server)
        expect(root_span.attributes["appsignal.tag.reported_by"]).to eq("puma_lowlevel_error")
      end
    end

    # This shouldn't happen if the EventHandler is set up correctly, but if
    # it's not it will create a new transaction.
    describe "creating a new transaction with the error when no active transaction" do
      def perform
        lowlevel_error(error, env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        expect do
          perform
        end.to change { created_transactions.count }.by(1)

        expect(last_transaction).to have_error("ExampleException", "error message")
        expect(last_transaction).to include_tags("reported_by" => "puma_lowlevel_error")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        expect do
          perform
        end.to change { created_transactions.count }.by(1)

        event = root_span.events.find { |e| e.name == "exception" }
        expect(event).not_to be_nil
        expect(event.attributes["exception.type"]).to eq("ExampleException")
        expect(event.attributes["exception.message"]).to eq("error message")
        expect(event.attributes["exception.stacktrace"]).to be_a(String)
        expect(event.attributes["appsignal.alert_this_error"]).to eq(true)
        expect(root_span.status.code).to eq(::OpenTelemetry::Trace::Status::ERROR)
        expect(root_span.kind).to eq(:server)
        expect(root_span.attributes["appsignal.tag.reported_by"]).to eq("puma_lowlevel_error")
      end
    end

    it_in_both_modes "doesn't report internal Puma errors" do
      expect do
        lowlevel_error(Puma::MiniSSL::SSLError.new("error message"), env)
        lowlevel_error(Puma::HttpParserError.new("error message"), env)
        lowlevel_error(Puma::HttpParserError501.new("error message"), env)
      end.to_not(change { created_transactions.count })
    end

    describe "request metadata" do
      def perform
        lowlevel_error(error, env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_metadata(
          "request_method" => "GET",
          "method" => "GET",
          "request_path" => "/some/path",
          "path" => "/some/path"
        )
        expect(last_transaction).to include_environment(
          "REQUEST_METHOD" => "GET",
          "PATH_INFO" => "/some/path"
          # and more, but we don't need to test Rack mock defaults
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        # Metadata is emitted as appsignal.tag.* attributes in collector mode
        expect(root_span.attributes["appsignal.tag.request_method"]).to eq("GET")
        expect(root_span.attributes["appsignal.tag.method"]).to eq("GET")
        expect(root_span.attributes["appsignal.tag.request_path"]).to eq("/some/path")
        expect(root_span.attributes["appsignal.tag.path"]).to eq("/some/path")
      end
    end

    describe "request parameters" do
      def perform
        lowlevel_error(error, env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_params(
          "page" => "2",
          "query" => "lorem"
        )
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        # The transaction uses the HTTP_REQUEST (web) namespace, so params are
        # stored under appsignal.request.payload.
        expect(JSON.parse(root_span.attributes["appsignal.request.payload"]))
          .to eq("page" => "2", "query" => "lorem")
      end
    end

    describe "session data" do
      def perform
        lowlevel_error(error, env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_session_data("session" => "data", "user_id" => 123)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        expect(JSON.parse(root_span.attributes["appsignal.request.session_data"]))
          .to eq("session" => "data", "user_id" => 123)
      end
    end

    describe "queue start" do
      def perform
        lowlevel_error(error, env)
      end

      # Queue start has no OpenTelemetry consumer; it is agent-only.
      it "sets the queue start", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to have_queue_start(queue_start_time)
      end

      it "completes without error in collector mode", :collector_mode do
        start_collector_agent
        expect { perform }.to_not raise_error
        expect(root_span).not_to be_nil
      end
    end

    describe "with Puma::Server#lowlevel_error accepting 3 arguments" do
      def perform(status = nil)
        lowlevel_error(error, env, status)
      end

      it "in agent mode", :agent_mode do
        start_agent
        result = perform(501)
        expect(result).to eq([501, {}, ""])

        expect(last_transaction).to include_tags("response_status" => 501)
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        result = perform(501)
        expect(result).to eq([501, {}, ""])

        expect(root_span.attributes["appsignal.tag.response_status"]).to eq(501)
      end
    end

    context "with Puma::Server#lowlevel_error accepting 2 arguments" do
      let(:puma_server) do
        Class.new do
          def lowlevel_error(_error, _env)
            [500, {}, ""]
          end
        end
      end

      describe "calls the super class with 2 arguments and sets the response status" do
        def perform
          lowlevel_error(error, env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          result = perform
          expect(result).to eq([500, {}, ""])

          expect(last_transaction).to include_tags("response_status" => 500)
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          result = perform
          expect(result).to eq([500, {}, ""])

          expect(root_span.attributes["appsignal.tag.response_status"]).to eq(500)
        end
      end
    end
  end

  def default_puma_server_mock
    Class.new do
      def lowlevel_error(_error, _env, status = 500)
        [status, {}, ""]
      end
    end
  end
end
