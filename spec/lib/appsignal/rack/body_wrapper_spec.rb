describe Appsignal::Rack::BodyWrapper do
  let(:transaction) { http_request_transaction }
  before do
    start_agent
    set_current_transaction(transaction)
  end

  describe "with a body that supports all possible features" do
    it "reduces the supported methods to just each()" do
      # which is the safest thing to do, since the body is likely broken
      fake_body = double(
        :each => nil,
        :call => nil,
        :to_ary => [],
        :to_path => "/tmp/foo.bin",
        :close => nil
      )

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to respond_to(:close)
    end
  end

  describe "with a body only supporting each()" do
    it "wraps with appropriate class" do
      fake_body = double(:each => nil)

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, transaction)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#each)"
      )
    end

    it "returns an Enumerator if each() gets called without a block" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, transaction)
      enum = wrapped.each
      expect(enum).to be_kind_of(Enumerator)
      expect { |b| enum.each(&b) }.to yield_successive_args("a", "b", "c")

      expect(transaction).to_not include_event("name" => "process_response_body.rack")
    end

    it "sets the exception raised inside each() on the transaction" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

      wrapped = described_class.wrap(fake_body, transaction)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end

    it "closes the body and tracks an instrumentation event when it gets closed" do
      fake_body = double(:close => nil)
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, transaction)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      wrapped.close

      expect(transaction).to include_event("name" => "close_response_body.rack")
    end
  end

  describe "with a body supporting both each() and call" do
    it "wraps with the wrapper that conceals call() and exposes each" do
      fake_body = double
      allow(fake_body).to receive(:each)
      allow(fake_body).to receive(:call)

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end
  end

  describe "with a body supporting both to_ary and each" do
    let(:fake_body) { double(:each => nil, :to_ary => []) }

    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each" do
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, transaction)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#each)"
      )
    end

    it "sets the exception raised inside each() into the Appsignal transaction" do
      expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

      wrapped = described_class.wrap(fake_body, transaction)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end

    it "reads out the body in full using to_ary" do
      expect(fake_body).to receive(:to_ary).and_return(["one", "two", "three"])

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped.to_ary).to eq(["one", "two", "three"])

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#to_ary)"
      )
    end

    it "sends the exception raised inside to_ary() into the Appsignal and closes transaction" do
      fake_body = double
      allow(fake_body).to receive(:each)
      expect(fake_body).to receive(:to_ary).once.and_raise(ExampleException, "error message")
      expect(fake_body).to_not receive(:close) # Per spec we expect the body has closed itself

      wrapped = described_class.wrap(fake_body, transaction)
      expect do
        wrapped.to_ary
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end
  end

  describe "with a body supporting both to_path and each" do
    let(:fake_body) { double(:each => nil, :to_path => nil) }

    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to_not respond_to(:call)
      expect(wrapped).to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each()" do
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, transaction)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#each)"
      )
    end

    it "sets the exception raised inside each() into the Appsignal transaction" do
      expect(fake_body).to receive(:each).once.and_raise(ExampleException, "error message")

      wrapped = described_class.wrap(fake_body, transaction)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end

    it "sets the exception raised inside to_path() into the Appsignal transaction" do
      allow(fake_body).to receive(:to_path).once.and_raise(ExampleException, "error message")

      wrapped = described_class.wrap(fake_body, transaction)
      expect do
        wrapped.to_path
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end

    it "exposes to_path to the sender" do
      allow(fake_body).to receive(:to_path).and_return("/tmp/file.bin")

      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped.to_path).to eq("/tmp/file.bin")

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#to_path)"
      )
    end
  end

  describe "with a body only supporting call()" do
    let(:fake_body) { double(:call => nil) }

    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, transaction)
      expect(wrapped).to_not respond_to(:each)
      expect(wrapped).to_not respond_to(:to_ary)
      expect(wrapped).to respond_to(:call)
      expect(wrapped).to_not respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "passes the stream into the call() of the body" do
      fake_rack_stream = double("stream")
      expect(fake_body).to receive(:call).with(fake_rack_stream)

      wrapped = described_class.wrap(fake_body, transaction)
      wrapped.call(fake_rack_stream)

      expect(transaction).to include_event(
        "name" => "process_response_body.rack",
        "title" => "Process Rack response body (#call)"
      )
    end

    it "sets the exception raised inside call() into the Appsignal transaction" do
      fake_rack_stream = double
      allow(fake_body).to receive(:call)
        .with(fake_rack_stream)
        .and_raise(ExampleException, "error message")

      wrapped = described_class.wrap(fake_body, transaction)

      expect do
        wrapped.call(fake_rack_stream)
      end.to raise_error(ExampleException, "error message")

      expect(transaction).to have_error("ExampleException", "error message")
    end
  end
end
