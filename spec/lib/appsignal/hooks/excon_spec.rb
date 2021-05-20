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

    it "should instrument a http request" do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("request.excon", "GET http://www.google.com", nil, 0)

      data = {
        :host => "www.google.com",
        :method => "get",
        :scheme => "http"
      }
      Excon.defaults[:instrumentor].instrument("excon.request", data) {}
    end

    it "should instrument a http response" do
      Appsignal::Transaction.create("uuid", Appsignal::Transaction::HTTP_REQUEST, "test")
      expect(Appsignal::Transaction.current).to receive(:start_event)
        .at_least(:once)
      expect(Appsignal::Transaction.current).to receive(:finish_event)
        .at_least(:once)
        .with("response.excon", "www.google.com", nil, 0)

      data = {
        :host => "www.google.com"
      }
      Excon.defaults[:instrumentor].instrument("excon.response", data) {}
    end
  end

  context "without Excon" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
