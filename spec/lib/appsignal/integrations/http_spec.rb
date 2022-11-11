# frozen_string_literal: true

if DependencyHelper.http_present?
  require "appsignal/integrations/http"

  describe Appsignal::Integrations::HttpIntegration do
    around do |example|
      keep_transactions { example.run }
    end

    before :context do
      start_agent
    end

    it "should instrument a HTTP request" do
      stub_request(:get, "http://www.google.com/")

      expect { HTTP.get("http://www.google.com") }
        .to change { created_transactions.length }.by(1)

      expect(last_transaction).to be_completed
      expect(last_transaction.to_h).to include("namespace" => Appsignal::Transaction::HTTP_REQUEST)
    end

    it "should instrument a HTTPS request" do
      stub_request(:get, "https://www.google.com/")

      expect { HTTP.get("https://www.google.com") }
        .to change { created_transactions.length }.by(1)

      expect(last_transaction).to be_completed
      expect(last_transaction.to_h).to include("namespace" => Appsignal::Transaction::HTTP_REQUEST)
    end

    context "with HTTP exception" do
      let(:error) { ExampleException.new("oh no!") }

      it "reports the exception and re-raises it" do
        stub_request(:get, "https://www.google.com/").and_raise(error)

        expect do
          expect do
            HTTP.get("https://www.google.com")
          end.to raise_error(ExampleException)
        end.to change { created_transactions.length }.by(1)

        transaction_hash = last_transaction.to_h

        expect(transaction_hash).to \
          include("namespace" => Appsignal::Transaction::HTTP_REQUEST)

        expect(transaction_hash["error"]).to include(
          "backtrace" => kind_of(String),
          "name" => error.class.name,
          "message" => error.message
        )
      end
    end
  end
end
