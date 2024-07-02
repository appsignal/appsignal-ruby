describe "Appsignal::Rack::GenericInstrumentation" do
  describe "Appsignal::Rack::GenericInstrumentation constant" do
    let(:err_stream) { std_stream }
    let(:stderr) { err_stream.read }
    before do
      if Appsignal::Rack.const_defined?(:GenericInstrumentation)
        hide_const "Appsignal::Rack::GenericInstrumentation"
      end
    end

    it "returns the Rack::GenericInstrumentation constant" do
      silence do
        expect(Appsignal::Rack::GenericInstrumentation)
          .to be(Appsignal::Rack::GenericInstrumentationAlias)
      end
    end

    it "prints a deprecation warning to STDERR" do
      capture_std_streams(std_stream, err_stream) do
        Appsignal::Rack::GenericInstrumentation
      end

      expect(stderr).to include(
        "appsignal WARNING: The constant Appsignal::Rack::GenericInstrumentation " \
          "has been deprecated."
      )
    end

    it "logs a warning" do
      logs =
        capture_logs do
          silence do
            Appsignal::Rack::GenericInstrumentation
          end
        end

      expect(logs).to contains_log(
        :warn,
        "The constant Appsignal::Rack::GenericInstrumentation has been deprecated."
      )
    end
  end

  describe "middleware" do
    let(:app) { double(:call => true) }
    let(:env) { Rack::MockRequest.env_for("/some/path") }
    let(:middleware) { Appsignal::Rack::GenericInstrumentation.new(app, {}) }

    before(:context) { start_agent }
    around { |example| keep_transactions { example.run } }

    def make_request(env)
      middleware.call(env)
    end

    context "without an exception" do
      it "reports a process_action.generic event" do
        make_request(env)

        expect(last_transaction).to include_event("name" => "process_action.generic")
      end
    end

    context "with action name env" do
      it "reports the appsignal.action env as the action name" do
        env["appsignal.action"] = "MyAction"
        make_request(env)

        expect(last_transaction).to have_action("MyAction")
      end
    end

    context "without action name metadata" do
      it "reports 'unknown' as the action name" do
        make_request(env)

        expect(last_transaction).to have_action("unknown")
      end
    end
  end
end
