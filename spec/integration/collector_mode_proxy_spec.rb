if DependencyHelper.opentelemetry_present?
  describe "AppSignal collector mode proxy" do
    before do
      OTLPCollectorServer.clear
      HTTPProxyServer.clear
    end

    it "sends every signal through the proxy in the http_proxy option" do
      runner = Runner.new(
        "collector_mode_emit",
        :env => OTLPCollectorServer.env.merge(HTTPProxyServer.env)
      )
      runner.run

      # A request sent through a proxy carries the whole URL in its request
      # line, where one sent straight to the server carries only the path.
      request_lines = Array.new(3) { HTTPProxyServer.listen[:line] }

      expect(request_lines).to contain_exactly(
        "POST #{OTLPCollectorServer.endpoint}/v1/traces HTTP/1.1",
        "POST #{OTLPCollectorServer.endpoint}/v1/metrics HTTP/1.1",
        "POST #{OTLPCollectorServer.endpoint}/v1/logs HTTP/1.1"
      )

      # The mock proxy answers requests itself rather than forwarding them,
      # so nothing reaching the collector proves nothing went around it.
      expect(OTLPCollectorServer.received.values.map(&:size)).to all(be_zero)
    end

    it "sends the credentials in the proxy address" do
      proxy_with_credentials =
        HTTPProxyServer.address.sub("http://", "http://user:secret@")
      runner = Runner.new(
        "collector_mode_emit",
        :env => OTLPCollectorServer.env
          .merge("APPSIGNAL_HTTP_PROXY" => proxy_with_credentials)
      )
      runner.run

      authorizations = Array.new(3) { HTTPProxyServer.listen[:authorization] }

      expect(authorizations)
        .to eq(["Basic #{["user:secret"].pack("m0")}"] * 3)
    end

    it "sends straight to the collector when no proxy is configured" do
      runner = Runner.new("collector_mode_emit", :env => OTLPCollectorServer.env)
      runner.run

      # Wait for every signal to reach the collector before asserting that the
      # proxy saw none of them, so that an empty proxy cannot mean "not sent
      # yet" rather than "not sent through the proxy".
      OTLPCollectorServer::PATHS.each { |path| OTLPCollectorServer.listen_to(path) }

      expect(HTTPProxyServer.received_count).to be_zero
    end
  end
end
