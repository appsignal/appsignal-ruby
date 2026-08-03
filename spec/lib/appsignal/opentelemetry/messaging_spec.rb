# frozen_string_literal: true

describe Appsignal::OpenTelemetry::Messaging do
  describe ".enqueue_attributes" do
    # Enqueuing a job is one of the five kinds of operation the conventions
    # define: it sends a message.
    it "describes a job being enqueued" do
      expect(described_class.enqueue_attributes("sidekiq")).to eq(
        "messaging.system" => "sidekiq",
        "messaging.operation.name" => "enqueue",
        "messaging.operation.type" => "send"
      )
    end

    it "names the queue the job is being put on" do
      expect(
        described_class.enqueue_attributes("sidekiq", :destination => "mailers")
      ).to include("messaging.destination.name" => "mailers")
    end
  end

  describe ".perform_attributes" do
    # Performing a job processes a message, which is another of the five.
    it "describes a job being performed" do
      expect(described_class.perform_attributes("resque")).to eq(
        "messaging.system" => "resque",
        "messaging.operation.name" => "perform",
        "messaging.operation.type" => "process"
      )
    end

    it "names the queue the job came off" do
      expect(
        described_class.perform_attributes("resque", :destination => "mailers")
      ).to include("messaging.destination.name" => "mailers")
    end
  end

  describe "a span that covers a batch" do
    it "says how many messages the batch holds" do
      expect(
        described_class.perform_attributes("aws_sqs", :batch_size => 3)
      ).to include("messaging.batch.message_count" => 3)
    end

    # The conventions say a span describing a single message must not carry a
    # count, so only a batch gets one.
    it "leaves out the count when the span is not a batch" do
      expect(described_class.perform_attributes("aws_sqs")).to_not have_key(
        "messaging.batch.message_count"
      )
    end

    it "leaves out a count of nothing" do
      expect(
        described_class.perform_attributes("aws_sqs", :batch_size => 0)
      ).to_not have_key("messaging.batch.message_count")
    end
  end

  # Not every job library records a queue, and not every job is on one, so the
  # attribute is left out rather than sent empty.
  it "leaves out a queue it was not given" do
    expect(described_class.perform_attributes("resque")).to_not have_key(
      "messaging.destination.name"
    )
    expect(
      described_class.perform_attributes("resque", :destination => "")
    ).to_not have_key("messaging.destination.name")
  end
end
