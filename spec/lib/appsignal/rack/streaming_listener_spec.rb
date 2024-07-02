describe "Appsignal::Rack::StreamingListener" do
  def load_middleware
    load "lib/appsignal/rack/streaming_listener.rb"
  end

  describe "loading the streaming_listener integrations file" do
    let(:err_stream) { std_stream }
    let(:stderr) { err_stream.read }
    after { Appsignal::Rack.send(:remove_const, :StreamingListener) }

    it "prints a deprecation warning to STDERR" do
      capture_std_streams(std_stream, err_stream) do
        load_middleware
      end

      expect(stderr).to include(
        "appsignal WARNING: The constant Appsignal::Rack::StreamingListener " \
          "has been deprecated."
      )
    end

    it "logs a warning" do
      logs =
        capture_logs do
          silence do
            load_middleware
          end
        end

      expect(logs).to contains_log(
        :warn,
        "The constant Appsignal::Rack::StreamingListener has been deprecated."
      )
    end
  end

  describe "middleware" do
    let(:env) { {} }
    let(:app) { DummyApp.new }
    let(:middleware) { Appsignal::Rack::StreamingListener.new(app, {}) }
    around { |example| keep_transactions { example.run } }
    before(:context) { load_middleware }
    before { start_agent }

    def make_request
      middleware.call(env)
    end

    it "instruments the call" do
      make_request

      expect(last_transaction).to include_event("name" => "process_streaming_request.rack")
    end

    it "set no action by default" do
      make_request

      expect(last_transaction).to_not have_action
    end

    it "set `appsignal.action` to the action name" do
      env["appsignal.action"] = "Action"

      make_request

      expect(last_transaction).to have_action("Action")
    end
  end
end
