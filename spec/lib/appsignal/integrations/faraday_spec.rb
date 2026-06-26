if DependencyHelper.faraday_present?
  require "faraday"
  require "appsignal/integrations/faraday"
  require "faraday/excon" if DependencyHelper.excon_present?

  # Integration test against the real Faraday gem. The hook auto-installs
  # Faraday's instrumentation middleware onto every connection, so the
  # `request.faraday` event fires without the user adding it themselves.
  describe "Faraday integration" do
    before { Appsignal::Hooks::FaradayHook.new.install }

    # The common case: the default adapter is Net::HTTP, which AppSignal also
    # instruments. Faraday suppresses it, so the request is recorded once -- as
    # the `request.faraday` event.
    describe "a request over the default Net::HTTP adapter" do
      def perform
        stub_request(:get, "http://www.example.com/")
        Faraday.new("http://www.example.com").get("/")
      end

      it "records the request once, as the Faraday event" do
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
        # Net::HTTP is suppressed under Faraday, so it isn't recorded again.
        expect(transaction).to_not include_event("name" => "request.net_http")
      end
    end

    # Excon is also a Faraday adapter, and AppSignal instruments it through
    # Excon's instrumentor. Faraday suppresses it too, so the request is recorded
    # once -- as the `request.faraday` event.
    describe "a request over the Excon adapter", :if => DependencyHelper.excon_present? do
      before { Appsignal::Hooks::ExconHook.new.install }

      def perform
        stub_request(:get, "http://www.example.com/")
        connection = Faraday.new("http://www.example.com") do |faraday|
          faraday.adapter :excon
        end
        connection.get("/")
      end

      it "records the request once, as the Faraday event" do
        start_agent
        transaction = http_request_transaction
        set_current_transaction(transaction)
        perform

        expect(transaction).to include_event(
          "name" => "request.faraday",
          "title" => "GET http://www.example.com",
          "body" => ""
        )
        # Excon is suppressed under Faraday, so it isn't recorded again.
        expect(transaction).to_not include_event("name" => "request.excon")
      end
    end
  end
end
