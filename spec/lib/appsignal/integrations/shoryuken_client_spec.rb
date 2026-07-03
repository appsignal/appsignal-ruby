if DependencyHelper.shoryuken_present?
  require "shoryuken"
  require "appsignal/integrations/shoryuken"

  # Integration test against the real Shoryuken gem and a stubbed AWS SQS client
  # (the shoryuken_spec.rb suite drives the middleware with doubles). Verifies, end
  # to end, that the hook registers the client middleware on the real send path and
  # that it writes trace context onto a live outgoing message -- the registration
  # the doubled suite can't prove.
  describe "Shoryuken client integration" do
    before { Appsignal::Hooks::ShoryukenHook.new.install }

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

    # Sends a real message through Shoryuken's send path and returns the params
    # the SQS client was called with.
    def send_message
      sent = nil
      allow(sqs_client).to receive(:send_message).and_wrap_original do |original, params|
        sent = params
        original.call(params)
      end
      queue.send_message(:message_body => "foo")
      sent
    end

    it "in agent mode", :agent_mode do
      start_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)

      sent = send_message

      event_names = transaction.to_h["events"].map { |event| event["name"] }
      expect(event_names).to include("enqueue.shoryuken")
      expect(sent).to_not have_key(:message_attributes)
    end

    it "in collector mode", :collector_mode do
      start_collector_agent
      transaction = http_request_transaction
      set_current_transaction(transaction)

      sent = send_message
      Appsignal::Transaction.complete_current!

      producer = event_spans.find { |s| s.name == "enqueue.shoryuken" }
      expect(producer.kind).to eq(:producer)

      # The middleware the hook registered injected the producer span's trace
      # context onto the real outgoing message, wire-equivalent to OpenTelemetry's
      # aws-sdk instrumentation.
      expect(sent[:message_attributes]["traceparent"]).to eq(
        :string_value => "00-#{producer.hex_trace_id}-#{producer.hex_span_id}-01",
        :data_type => "String"
      )
    end
  end
end
