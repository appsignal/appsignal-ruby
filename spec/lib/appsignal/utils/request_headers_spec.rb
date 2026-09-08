describe Appsignal::Utils::RequestHeaders do
  describe ".split" do
    def split(env)
      described_class.split(env)
    end

    it "returns the headers under their OpenTelemetry name" do
      headers, environment = split(
        "HTTP_ACCEPT" => "text/html",
        "HTTP_CACHE_CONTROL" => "max-age=0"
      )

      expect(headers).to eq(
        "accept" => "text/html",
        "cache-control" => "max-age=0"
      )
      expect(environment).to be_empty
    end

    it "returns the headers Rack passes without a prefix" do
      headers, environment = split(
        "CONTENT_LENGTH" => "12",
        "CONTENT_TYPE" => "application/json"
      )

      expect(headers).to eq(
        "content-length" => "12",
        "content-type" => "application/json"
      )
      expect(environment).to be_empty
    end

    it "returns everything else under its Rack name" do
      headers, environment = split(
        "PATH_INFO" => "/some-path",
        "REQUEST_METHOD" => "GET",
        "MY_CUSTOM_KEY" => "my value"
      )

      expect(headers).to be_empty
      expect(environment).to eq(
        "PATH_INFO" => "/some-path",
        "REQUEST_METHOD" => "GET",
        "MY_CUSTOM_KEY" => "my value"
      )
    end

    it "returns HTTP_VERSION as an environment value" do
      headers, environment = split("HTTP_VERSION" => "HTTP/1.1")

      expect(headers).to be_empty
      expect(environment).to eq("HTTP_VERSION" => "HTTP/1.1")
    end

    it "splits a mixed environment" do
      headers, environment = split(
        "HTTP_ACCEPT" => "text/html",
        "CONTENT_LENGTH" => "12",
        "HTTP_VERSION" => "HTTP/1.1",
        "REMOTE_ADDR" => "127.0.0.1"
      )

      expect(headers).to eq(
        "accept" => "text/html",
        "content-length" => "12"
      )
      expect(environment).to eq(
        "HTTP_VERSION" => "HTTP/1.1",
        "REMOTE_ADDR" => "127.0.0.1"
      )
    end

    it "accepts keys that aren't Strings" do
      headers, environment = split(
        :HTTP_ACCEPT => "text/html",
        :REMOTE_ADDR => "127.0.0.1"
      )

      expect(headers).to eq("accept" => "text/html")
      expect(environment).to eq(:REMOTE_ADDR => "127.0.0.1")
    end
  end

  describe ".header_name" do
    def header_name(env_key)
      described_class.header_name(env_key)
    end

    it "returns the OpenTelemetry name of a header" do
      expect(header_name("HTTP_ACCEPT")).to eq("accept")
      expect(header_name("HTTP_ACCEPT_CHARSET")).to eq("accept-charset")
      expect(header_name("CONTENT_LENGTH")).to eq("content-length")
    end

    it "returns nil for a key that doesn't hold a header" do
      expect(header_name("PATH_INFO")).to be_nil
      expect(header_name("SERVER_PROTOCOL")).to be_nil
      expect(header_name("HTTP_VERSION")).to be_nil
    end
  end

  describe ".rack_name" do
    def rack_name(header)
      described_class.rack_name(header)
    end

    it "returns the Rack name of a header" do
      expect(rack_name("accept")).to eq("HTTP_ACCEPT")
      expect(rack_name("accept-charset")).to eq("HTTP_ACCEPT_CHARSET")
    end

    it "returns the unprefixed Rack name for the two headers Rack reserves" do
      expect(rack_name("content-length")).to eq("CONTENT_LENGTH")
      expect(rack_name("content-type")).to eq("CONTENT_TYPE")
    end

    it "returns the same Rack name a header was read from" do
      %w[
        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_X_FOO CONTENT_LENGTH CONTENT_TYPE
      ].each do |env_key|
        expect(rack_name(described_class.header_name(env_key))).to eq(env_key)
      end
    end

    it "returns the same Rack name for two keys that name one header" do
      # A server that sets both of these gives the prefixed one back under the
      # unprefixed name, which is the spelling Rack is supposed to use.
      expect(described_class.header_name("CONTENT_LENGTH")).to eq("content-length")
      expect(described_class.header_name("HTTP_CONTENT_LENGTH")).to eq("content-length")
      expect(rack_name("content-length")).to eq("CONTENT_LENGTH")
    end
  end
end
