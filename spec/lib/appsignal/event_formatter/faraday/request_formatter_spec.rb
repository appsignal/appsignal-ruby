describe Appsignal::EventFormatter::Faraday::RequestFormatter do
  let(:klass)     { Appsignal::EventFormatter::Faraday::RequestFormatter }
  let(:formatter) { klass.new }

  it "should register request.faraday" do
    Appsignal::EventFormatter.registered?("request.faraday", klass).should be_true
  end

  describe "#format" do
    let(:payload) do
      {
        method: :get,
        url: URI.parse("http://example.org/hello/world?some=param")
      }
    end

    subject { formatter.format(payload) }

    it { should eq ["GET http://example.org", "GET http://example.org/hello/world"] }
  end
end
