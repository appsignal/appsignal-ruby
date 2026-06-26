if DependencyHelper.faraday_present?
  require "faraday"
  require "appsignal/integrations/faraday"

  # Integration test against the real Faraday gem. The hook auto-installs
  # Faraday's instrumentation middleware onto every connection, so the
  # `request.faraday` event fires without the user adding it themselves.
  describe "Faraday integration" do
    before { Appsignal::Hooks::FaradayHook.new.install }

    # The common case: the default adapter is Net::HTTP, which AppSignal also
    # instruments. So a Faraday request nests two client events -- the
    # `request.faraday` event around the `request.net_http` event.
    describe "a request over the default Net::HTTP adapter" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Faraday.new("http://www.example.com").get("/")
      end

      it "records the Faraday request" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        # Title only, no body -- the path is left out, matching Net::HTTP.
        expect(transaction).to include_event(
          "name" => "request.faraday",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
      end
    end
  end
end
