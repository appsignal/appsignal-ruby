describe Appsignal::Hooks::ExconHook do
  before :context do
    start_agent
  end

  context "with Excon" do
    before(:context) do
      class Excon
        def self.defaults
          @defaults ||= {}
        end
      end
      Appsignal::Hooks::ExconHook.new.install
    end
    after(:context) { Object.send(:remove_const, :Excon) }

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    describe "#install" do
      it "adds the AppSignal instrumentor to Excon" do
        expect(Excon.defaults[:instrumentor]).to eql(Appsignal::Integrations::ExconIntegration)
      end
    end

    describe "instrumentation" do
      let!(:transaction) do
        Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
      end
      around { |example| keep_transactions { example.run } }

      it "instruments a http request" do
        data = {
          :host => "www.google.com",
          :method => :get,
          :scheme => "http"
        }
        Excon.defaults[:instrumentor].instrument("excon.request", data) {} # rubocop:disable Lint/EmptyBlock

        expect(transaction.to_h["events"]).to include(
          hash_including(
            "name" => "request.excon",
            "title" => "GET http://www.google.com",
            "body" => ""
          )
        )
      end

      it "instruments a http response" do
        data = { :host => "www.google.com" }
        Excon.defaults[:instrumentor].instrument("excon.response", data) {} # rubocop:disable Lint/EmptyBlock

        expect(transaction.to_h["events"]).to include(
          hash_including(
            "name" => "response.excon",
            "title" => "www.google.com",
            "body" => ""
          )
        )
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
