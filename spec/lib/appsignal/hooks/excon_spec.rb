describe Appsignal::Hooks::ExconHook do
  context "with Excon" do
    before do
      stub_const("Excon", Class.new do
        def self.defaults
          # Mock is the innermost default middleware; the hook inserts ours
          # before it. Referenced lazily so it's resolved after the stub below.
          @defaults ||= { :middlewares => [Excon::Middleware::Mock] }
        end
      end)
      stub_const("Excon::Middleware", Module.new)
      stub_const("Excon::Middleware::Base", Class.new do
        def initialize(stack = nil)
          @stack = stack
        end

        # The default `request_call` just returns the datum, standing in for the
        # rest of the (empty) middleware stack.
        def request_call(datum)
          datum
        end
      end)
      stub_const("Excon::Middleware::Mock", Class.new(Excon::Middleware::Base))
      Appsignal::Hooks::ExconHook.new.install
    end

    describe "#dependencies_present?" do
      before { start_agent }
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    describe "#install" do
      it "adds the AppSignal instrumentor to Excon" do
        expect(Excon.defaults[:instrumentor]).to eql(Appsignal::Integrations::ExconIntegration)
      end

      it "adds the AppSignal middleware to Excon, before the Mock middleware" do
        middlewares = Excon.defaults[:middlewares]
        expect(middlewares).to include(Appsignal::Integrations::ExconMiddleware)
        expect(middlewares.index(Appsignal::Integrations::ExconMiddleware))
          .to be < middlewares.index(Excon::Middleware::Mock)
      end

      it "does not add the middleware twice when installed again" do
        Appsignal::Hooks::ExconHook.new.install
        expect(
          Excon.defaults[:middlewares].count(Appsignal::Integrations::ExconMiddleware)
        ).to eq(1)
      end
    end

    describe "instrumentation" do
      describe "a http request" do
        def perform
          data = {
            :host => "www.google.com",
            :method => :get,
            :scheme => "http"
          }
          Excon.defaults[:instrumentor].instrument("excon.request", data) do
            # The middleware injects from whatever span is current. The
            # instrumentor's event span is active here, mirroring a real
            # request where the middleware runs inside the instrumented block.
            datum = inject_with_middleware
          ensure
            @injected_headers = datum && datum[:headers]
          end
        end

        # Runs the AppSignal Excon middleware's `request_call` over an empty
        # datum, returning the datum so we can read the injected headers.
        def inject_with_middleware
          middleware = Appsignal::Integrations::ExconMiddleware.new
          middleware.request_call({})
        end

        it "in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "request.excon",
            "title" => "GET http://www.google.com",
            "body" => ""
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(http_request_transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.kind).to eq(:client)
          expect(span.parent_span_id).to eq(root_span.span_id)
          expect(span.attributes["appsignal.category"]).to eq("request.excon")
          expect(span.attributes).not_to have_key("appsignal.body")

          # The middleware wrote a W3C traceparent for the client span onto the
          # outgoing request headers, so the called service joins this trace.
          expect(@injected_headers["traceparent"])
            .to eq("00-#{span.hex_trace_id}-#{span.hex_span_id}-01")
        end
      end

      describe "a http response" do
        def perform
          data = { :host => "www.google.com" }
          Excon.defaults[:instrumentor].instrument("excon.response", data) {} # rubocop:disable Lint/EmptyBlock
        end

        it "in agent mode", :agent_mode do
          start_agent
          transaction = http_request_transaction
          set_current_transaction(transaction)
          perform

          expect(transaction).to include_event(
            "name" => "response.excon",
            "title" => "www.google.com",
            "body" => ""
          )
        end

        it "in collector mode", :collector_mode do
          start_collector_agent
          set_current_transaction(http_request_transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("www.google.com")
          expect(span.parent_span_id).to eq(root_span.span_id)
          expect(span.attributes["appsignal.category"]).to eq("response.excon")
          expect(span.attributes).not_to have_key("appsignal.body")
        end
      end
    end
  end

  context "without Excon" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
