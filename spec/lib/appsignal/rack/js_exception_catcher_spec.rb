describe Appsignal::Rack::JSExceptionCatcher do
  let(:app)            { double(:call => true) }
  let(:options)        { nil }
  let(:config_options) { { :enable_frontend_error_catching => true } }
  let(:config)         { project_fixture_config("production", config_options) }
  let(:deprecation_message) do
    "The Appsignal::Rack::JSExceptionCatcher is deprecated. " \
      "Please use the official AppSignal JavaScript integration instead. " \
      "https://docs.appsignal.com/front-end/"
  end
  before { Appsignal.config = config }

  describe "#initialize" do
    it "logs to the logger" do
      stdout = std_stream
      stderr = std_stream
      log = capture_logs do
        capture_std_streams(stdout, stderr) do
          Appsignal::Rack::JSExceptionCatcher.new(app, options)
        end
      end
      expect(log).to contains_log(:warn, deprecation_message)
      expect(log).to contains_log(:debug, "Initializing Appsignal::Rack::JSExceptionCatcher")
      expect(stdout.read).to include "appsignal WARNING: #{deprecation_message}"
      expect(stderr.read).to_not include("appsignal:")
    end
  end

  describe "#call" do
    let(:catcher) do
      silence { Appsignal::Rack::JSExceptionCatcher.new(app, options) }
    end
    after { catcher.call(env) }

    context "when path is not frontend_error_catching_path" do
      let(:env) { { "PATH_INFO" => "/foo" } }

      context "when AppSignal is not active" do
        before { config[:active] = false }

        it "calls the next middleware" do
          expect(app).to receive(:call).with(env)
        end
      end

      context "when AppSignal is active" do
        before { config[:active] = true }

        it "calls the next middleware" do
          expect(app).to receive(:call).with(env)
        end
      end
    end

    context "when path is frontend_error_catching_path" do
      let(:transaction) { double(:complete! => true) }
      let(:env) do
        {
          "PATH_INFO"  => "/appsignal_error_catcher",
          "rack.input" => double(:read => '{"name": "error"}')
        }
      end

      context "when AppSignal is not active" do
        before { config[:active] = false }

        it "doesn't create an AppSignal transaction" do
          expect(Appsignal::JSExceptionTransaction).to_not receive(:new)
        end

        it "returns a 202 status" do
          expect(catcher.call(env)).to eq(
            [202, {}, ["AppSignal JavaScript error catching endpoint is not active."]]
          )
        end
      end

      context "when AppSignal is active" do
        before { config[:active] = true }

        it "creates a JSExceptionTransaction" do
          expect(Appsignal::JSExceptionTransaction).to receive(:new)
            .with("name" => "error")
            .and_return(transaction)

          expect(transaction).to receive(:complete!)
        end

        it "returns 200" do
          allow(Appsignal::JSExceptionTransaction).to receive(:new)
            .and_return(transaction)

          expect(catcher.call(env)).to eq([200, {}, []])
        end

        context "when request payload is empty" do
          let(:env) do
            {
              "PATH_INFO"  => "/appsignal_error_catcher",
              "rack.input" => double(:read => "")
            }
          end

          it "does not create a transaction" do
            expect(Appsignal::JSExceptionTransaction).to_not receive(:new)
          end

          it "returns 400" do
            expect(catcher.call(env)).to eq([400, {}, ["Request payload is not valid JSON."]])
          end
        end

        context "when `frontend_error_catching_path` is different" do
          let(:config_options) { { :frontend_error_catching_path => "/foo" } }

          it "does not create a transaction" do
            expect(Appsignal::JSExceptionTransaction).to_not receive(:new)
          end

          it "calls the next middleware" do
            expect(app).to receive(:call).with(env)
          end
        end

        context "when `name` is empty" do
          let(:env) do
            {
              "PATH_INFO"  => "/appsignal_error_catcher",
              "rack.input" => double(:read => '{"name": ""}')
            }
          end

          it "does not create a transaction" do
            expect(Appsignal::JSExceptionTransaction).to_not receive(:new)
          end

          it "returns 422" do
            expect(catcher.call(env)).to eq([422, {}, []])
          end
        end

        context "when `name` doesn't exist" do
          let(:env) do
            {
              "PATH_INFO"  => "/appsignal_error_catcher",
              "rack.input" => double(:read => '{"foo": ""}')
            }
          end

          it "does not create a transaction" do
            expect(Appsignal::JSExceptionTransaction).to_not receive(:new)
          end

          it "returns 422" do
            expect(catcher.call(env)).to eq([422, {}, []])
          end
        end
      end
    end
  end
end
