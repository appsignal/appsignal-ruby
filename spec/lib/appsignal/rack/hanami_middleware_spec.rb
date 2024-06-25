require "appsignal/rack/hanami_middleware"

if DependencyHelper.hanami2_present?
  describe Appsignal::Rack::HanamiMiddleware do
    let(:app) { double(:call => true) }
    let(:router_params) { { "param1" => "value1", "param2" => "value2" } }
    let(:env) do
      Rack::MockRequest.env_for(
        "/some/path",
        "router.params" => router_params
      )
    end
    let(:middleware) { Appsignal::Rack::HanamiMiddleware.new(app, {}) }

    before(:context) { start_agent }
    around { |example| keep_transactions { example.run } }

    def make_request(env)
      middleware.call(env)
    end

    context "with params" do
      it "sets request parameters on the transaction" do
        make_request(env)

        expect(last_transaction.to_h).to include(
          "sample_data" => hash_including(
            "params" => { "param1" => "value1", "param2" => "value2" }
          )
        )
      end
    end

    it "reports a process_action.hanami event" do
      make_request(env)

      expect(last_transaction.to_h).to include(
        "events" => [
          hash_including(
            "body" => "",
            "body_format" => Appsignal::EventFormatter::DEFAULT,
            "count" => 1,
            "name" => "process_action.hanami",
            "title" => ""
          )
        ]
      )
    end
  end
end
