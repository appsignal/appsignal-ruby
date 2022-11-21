# frozen_string_literal: true

if DependencyHelper.http_present?
  require "appsignal/integrations/http"

  describe Appsignal::Integrations::HttpIntegration do
    let(:transaction) { http_request_transaction }

    around do |example|
      keep_transactions { example.run }
    end

    before :context do
      start_agent
    end

    before do
      set_current_transaction(transaction)
    end

    it "instruments a HTTP request" do
      stub_request(:get, "http://www.google.com")

      HTTP.get("http://www.google.com")

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include("namespace" => Appsignal::Transaction::HTTP_REQUEST)
      expect(transaction_hash["events"].first).to include(
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "name" => "request.http_rb",
        "title" => "GET http://www.google.com"
      )
    end

    it "instruments a HTTPS request" do
      stub_request(:get, "https://www.google.com")

      HTTP.get("https://www.google.com")

      transaction_hash = transaction.to_h
      expect(transaction_hash).to include("namespace" => Appsignal::Transaction::HTTP_REQUEST)
      expect(transaction_hash["events"].first).to include(
        "body" => "",
        "body_format" => Appsignal::EventFormatter::DEFAULT,
        "name" => "request.http_rb",
        "title" => "GET https://www.google.com"
      )
    end

    context "with request parameters" do
      it "does not include the query parameters in the title" do
        stub_request(:get, "https://www.google.com?q=Appsignal")

        HTTP.get("https://www.google.com", :params => { :q => "Appsignal" })

        expect(transaction.to_h["events"].first).to include(
          "body" => "",
          "title" => "GET https://www.google.com"
        )
      end

      it "does not include the request body in the title" do
        stub_request(:post, "https://www.google.com")
          .with(:body => { :q => "Appsignal" }.to_json)

        HTTP.post("https://www.google.com", :json => { :q => "Appsignal" })

        expect(transaction.to_h["events"].first).to include(
          "body" => "",
          "title" => "POST https://www.google.com"
        )
      end
    end

    context "with an HTTP exception" do
      let(:error) { ExampleException.new("oh no!") }

      it "reports the exception and re-raises it" do
        stub_request(:get, "https://www.google.com").and_raise(error)

        expect do
          HTTP.get("https://www.google.com")
        end.to raise_error(ExampleException)

        transaction_hash = transaction.to_h
        expect(transaction_hash).to include("namespace" => Appsignal::Transaction::HTTP_REQUEST)
        expect(transaction_hash["events"].first).to include(
          "body" => "",
          "body_format" => Appsignal::EventFormatter::DEFAULT,
          "name" => "request.http_rb",
          "title" => "GET https://www.google.com"
        )

        expect(transaction_hash["error"]).to include(
          "backtrace" => kind_of(String),
          "name" => error.class.name,
          "message" => error.message
        )
      end
    end

    context "with various URI objects" do
      it "parses an object responding to #to_s" do
        request_uri = Struct.new(:uri) do
          def to_s
            uri.to_s
          end
        end

        stub_request(:get, "http://www.google.com")

        HTTP.get(request_uri.new("http://www.google.com"))

        expect(transaction.to_h["events"].first).to include(
          "name" => "request.http_rb",
          "title" => "GET http://www.google.com"
        )
      end

      it "parses an URI object" do
        stub_request(:get, "http://www.google.com")

        HTTP.get(URI("http://www.google.com"))

        expect(transaction.to_h["events"].first).to include(
          "name" => "request.http_rb",
          "title" => "GET http://www.google.com"
        )
      end

      it "parses a String object" do
        stub_request(:get, "http://www.google.com")

        HTTP.get("http://www.google.com")

        expect(transaction.to_h["events"].first).to include(
          "name" => "request.http_rb",
          "title" => "GET http://www.google.com"
        )
      end
    end
  end
end
