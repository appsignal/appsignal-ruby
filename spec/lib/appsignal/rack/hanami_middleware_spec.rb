require "appsignal/rack/hanami_middleware"

if DependencyHelper.hanami2_present?
  describe Appsignal::Rack::HanamiMiddleware do
    let(:app) { double(:call => true) }
    let(:router_params) { nil }
    let(:env) do
      options = {}
      options["router.params"] = router_params if router_params
      Rack::MockRequest.env_for(
        "/some/path",
        options
      )
    end
    let(:middleware) { Appsignal::Rack::HanamiMiddleware.new(app, {}) }

    def make_request(env)
      if DependencyHelper.hanami2_2_present?
        instance =
          Class.new do
            def self.name
              "HanamiApp::Actions::Books::Index"
            end
          end.new
        env["hanami.action_instance"] = instance
      end
      middleware.call(env)
    end

    context "without params" do
      describe "sets no request parameters on the transaction" do
        def perform
          make_request(env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to_not include_params
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.attributes.keys).to_not include("appsignal.request.payload")
        end
      end
    end

    context "with params" do
      let(:router_params) { { "param1" => "value1", "param2" => "value2" } }

      describe "sets request parameters on the transaction" do
        def perform
          make_request(env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to include_params("param1" => "value1", "param2" => "value2")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.kind).to eq(:server)
          params = JSON.parse(root_span.attributes["appsignal.request.payload"])
          expect(params).to include("param1" => "value1", "param2" => "value2")
        end
      end
    end

    describe "reports a process_action.hanami event" do
      def perform
        make_request(env)
      end

      it "in agent mode", :agent_mode do
        start_agent
        perform

        expect(last_transaction).to include_event("name" => "process_action.hanami")
      end

      it "in collector mode", :collector_mode do
        start_collector_agent
        perform

        span = event_spans.find { |s| s.name == "process_action.hanami" }
        expect(span).not_to be_nil
        expect(span.parent_span_id).to eq(root_span.span_id)
      end
    end

    if DependencyHelper.hanami2_2_present?
      describe "sets action name on the transaction" do
        def perform
          make_request(env)
        end

        it "in agent mode", :agent_mode do
          start_agent
          perform

          expect(last_transaction).to have_action("HanamiApp::Actions::Books::Index")
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          perform

          expect(root_span.name).to eq("HanamiApp::Actions::Books::Index")
          expect(root_span.attributes["appsignal.action_name"])
            .to eq("HanamiApp::Actions::Books::Index")
        end
      end
    end
  end
end
