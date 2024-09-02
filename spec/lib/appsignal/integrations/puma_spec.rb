require "appsignal/integrations/puma"

describe Appsignal::Integrations::PumaServer do
  describe "#lowlevel_error" do
    before do
      stub_const("Puma", PumaMock)
      stub_const("Puma::Server", puma_server)
      start_agent
    end
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
    before { Appsignal::Hooks::PumaHook.new.install }

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

    describe "error reporting" do
      let(:puma_server) { default_puma_server_mock }

      context "with active transaction" do
        before { create_transaction }

        it "reports the error to the transaction" do
          expect do
            lowlevel_error(error, env)
          end.to_not(change { created_transactions.count })

          expect(last_transaction).to have_error("ExampleException", "error message")
          expect(last_transaction).to include_tags("reported_by" => "puma_lowlevel_error")
        end
      end

      # This shouldn't happen if the EventHandler is set up correctly, but if
      # it's not it will create a new transaction.
      context "without active transaction" do
        it "creates a new transaction with the error" do
          expect do
            lowlevel_error(error, env)
          end.to change { created_transactions.count }.by(1)

          expect(last_transaction).to have_error("ExampleException", "error message")
          expect(last_transaction).to include_tags("reported_by" => "puma_lowlevel_error")
        end
      end

      it "doesn't report internal Puma errors" do
        expect do
          lowlevel_error(Puma::MiniSSL::SSLError.new("error message"), env)
          lowlevel_error(Puma::HttpParserError.new("error message"), env)
          lowlevel_error(Puma::HttpParserError501.new("error message"), env)
        end.to_not(change { created_transactions.count })
      end

      describe "request metadata" do
        it "sets request metadata" do
          lowlevel_error(error, env)

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

        it "sets request parameters" do
          lowlevel_error(error, env)

          expect(last_transaction).to include_params(
            "page" => "2",
            "query" => "lorem"
          )
        end

        it "sets session data" do
          lowlevel_error(error, env)

          expect(last_transaction).to include_session_data("session" => "data", "user_id" => 123)
        end

        it "sets the queue start" do
          lowlevel_error(error, env)

          expect(last_transaction).to have_queue_start(queue_start_time)
        end
      end
    end

    context "with Puma::Server#lowlevel_error accepting 3 arguments" do
      let(:puma_server) { default_puma_server_mock }

      it "calls the super class with 3 arguments" do
        result = lowlevel_error(error, env, 501)
        expect(result).to eq([501, {}, ""])

        expect(last_transaction).to include_tags("response_status" => 501)
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

      it "calls the super class with 3 arguments" do
        result = lowlevel_error(error, env)
        expect(result).to eq([500, {}, ""])

        expect(last_transaction).to include_tags("response_status" => 500)
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
