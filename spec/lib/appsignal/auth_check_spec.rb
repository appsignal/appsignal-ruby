describe Appsignal::AuthCheck do
  let(:config) { project_fixture_config }
  let(:auth_check) { Appsignal::AuthCheck.new(config) }
  let(:auth_url) do
    query = build_uri_query_string(
      :api_key => config[:push_api_key],
      :environment => config.env,
      :gem_version => Appsignal::VERSION,
      :hostname => config[:hostname],
      :name => config[:name]
    )

    URI(config[:endpoint]).tap do |uri|
      uri.path = "/1/auth"
      uri.query = query
    end.to_s
  end
  let(:stubbed_request) do
    WebMock.stub_request(:post, auth_url).with(:body => "{}")
  end

  def build_uri_query_string(hash)
    URI.encode_www_form(hash)
  end

  describe "#perform" do
    subject { auth_check.perform }

    context "when performing a request against the push api" do
      before { stubbed_request.to_return(:status => 200) }

      it "returns status code" do
        is_expected.to eq("200")
      end
    end

    context "when encountering an exception" do
      before { stubbed_request.to_timeout }

      it "raises an error" do
        expect { subject }.to raise_error(Net::OpenTimeout)
      end
    end
  end

  describe "#perform_with_result" do
    subject { auth_check.perform_with_result }

    context "when successful response" do
      before { stubbed_request.to_return(:status => 200) }

      it "returns success tuple" do
        is_expected.to eq ["200", "AppSignal has confirmed authorization!"]
      end
    end

    context "when unauthorized response" do
      before { stubbed_request.to_return(:status => 401) }

      it "returns unauthorirzed tuple" do
        is_expected.to eq ["401", "API key not valid with AppSignal..."]
      end
    end

    context "when unrecognized response" do
      before { stubbed_request.to_return(:status => 500) }

      it "returns an error tuple" do
        is_expected.to eq ["500", "Could not confirm authorization: 500"]
      end
    end

    context "when encountering an exception" do
      before { stubbed_request.to_timeout }

      it "returns an error tuple" do
        is_expected.to eq [
          nil,
          "Something went wrong while trying to authenticate with AppSignal: execution expired"
        ]
      end
    end
  end
end
