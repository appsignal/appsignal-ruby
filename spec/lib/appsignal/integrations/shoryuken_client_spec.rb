if DependencyHelper.shoryuken_present?
  require "shoryuken"
  require "appsignal/integrations/shoryuken"

  # Integration test against the real Shoryuken gem and a stubbed AWS SQS client
  # (the shoryuken_spec.rb suite drives the middleware with doubles). Verifies,
  # end to end, that the hook registers the client middleware on the real send
  # path and that an enqueue records an `enqueue.shoryuken` event -- the
  # registration the doubled suite can't prove.
  describe "Shoryuken client integration" do
    before do
      start_agent
      Appsignal::Hooks::ShoryukenHook.new.install
    end
    around { |example| keep_transactions { example.run } }

    after do
      ::Shoryuken.client_middleware.remove(Appsignal::Integrations::ShoryukenClientMiddleware)
      ::Shoryuken.server_middleware.remove(Appsignal::Integrations::ShoryukenMiddleware)
    end

    let(:sqs_client) do
      client = Aws::SQS::Client.new(:stub_responses => true, :region => "us-east-1")
      client.stub_responses(
        :get_queue_url,
        :queue_url => "https://sqs.us-east-1.amazonaws.com/0/test-queue"
      )
      client
    end
    let(:queue) { Shoryuken::Queue.new(sqs_client, "test-queue") }

    it "records an enqueue event through the real send path" do
      transaction = http_request_transaction
      set_current_transaction(transaction)

      queue.send_message(:message_body => "foo")

      event_names = transaction.to_h["events"].map { |event| event["name"] }
      expect(event_names).to include("enqueue.shoryuken")
    end
  end
end
