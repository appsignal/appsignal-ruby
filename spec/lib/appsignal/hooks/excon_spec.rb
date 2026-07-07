describe Appsignal::Hooks::ExconHook do
  context "with Excon" do
    before do
      stub_const("Excon", Class.new do
        def self.defaults
          @defaults ||= {}
        end
      end)
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
    end

    describe "instrumentation" do
      describe "a http request" do
        def perform
          data = {
            :host => "www.google.com",
            :method => :get,
            :scheme => "http"
          }
          Excon.defaults[:instrumentor].instrument("excon.request", data) {} # rubocop:disable Lint/EmptyBlock
        end

        it "in agent mode", :agent_mode do
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
          transaction = http_request_transaction
          set_current_transaction(transaction)
          perform
          Appsignal::Transaction.complete_current!

          expect(event_spans.size).to eq(1)
          span = event_spans.first
          expect(span.name).to eq("GET http://www.google.com")
          expect(span.parent_span_id).to eq(root_span.span_id)
          expect(span.attributes["appsignal.category"]).to eq("request.excon")
          expect(span.attributes).not_to have_key("appsignal.body")
        end
      end

      describe "a http response" do
        def perform
          data = { :host => "www.google.com" }
          Excon.defaults[:instrumentor].instrument("excon.response", data) {} # rubocop:disable Lint/EmptyBlock
        end

        it "in agent mode", :agent_mode do
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
          transaction = http_request_transaction
          set_current_transaction(transaction)
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
    before { hide_const "Excon" }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
