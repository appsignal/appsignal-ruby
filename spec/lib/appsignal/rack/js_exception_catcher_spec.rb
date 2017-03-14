describe Appsignal::Rack::JSExceptionCatcher do
  let(:app)            { double(:call => true) }
  let(:options)        { nil }
  let(:config_options) { { :enable_frontend_error_catching => true } }
  let(:config)         { project_fixture_config("production", config_options) }
  before { Appsignal.config = config }

  describe "#initialize" do
    it "logs to the logger" do
      expect(Appsignal.logger).to receive(:debug)
        .with("Initializing Appsignal::Rack::JSExceptionCatcher")

      Appsignal::Rack::JSExceptionCatcher.new(app, options)
    end
  end

  describe "#call" do
    let(:catcher) { Appsignal::Rack::JSExceptionCatcher.new(app, options) }
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
