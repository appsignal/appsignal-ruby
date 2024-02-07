describe Appsignal::Rack::BodyWrapper do
  describe "with a body that supports all possible features" do
    it "reduces the supported methods to just each()" do
      # which is the safest thing to do, since the body is likely broken
      fake_body = double(:each => nil, :call => nil, :to_ary => [], :to_path => "/tmp/foo.bin",
        :close => nil)
      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).not_to respond_to(:to_ary)
      expect(wrapped).not_to respond_to(:call)
      expect(wrapped).to respond_to(:close)
    end
  end

  describe "with a body only supporting each()" do
    it "wraps with appropriate class" do
      fake_body = double
      allow(fake_body).to receive(:each)

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).not_to respond_to(:to_ary)
      expect(wrapped).not_to respond_to(:call)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")
      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
    end

    it "returns an Enumerator if each() gets called without a block" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, _txn = nil)
      enum = wrapped.each
      expect(enum).to be_kind_of(Enumerator)
      expect { |b| enum.each(&b) }.to yield_successive_args("a", "b", "c")
    end

    it "sets the exception raised inside each() into the Appsignal transaction" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_raise(Exception.new("Oops"))

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))

      wrapped = described_class.wrap(fake_body, txn)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(/Oops/)
    end

    it "closes the body and the transaction when it gets closed" do
      fake_body = double
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      txn = double("Appsignal transaction")
      expect(Appsignal::Transaction).to receive(:complete_current!).once

      wrapped = described_class.wrap(fake_body, txn)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      expect { wrapped.close }.not_to raise_error
    end
  end

  describe "with a body supporting both each() and call" do
    it "wraps with the wrapper that conceals call() and exposes each" do
      fake_body = double
      allow(fake_body).to receive(:each)
      allow(fake_body).to receive(:call)

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).not_to respond_to(:to_ary)
      expect(wrapped).not_to respond_to(:call)
      expect(wrapped).not_to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end
  end

  describe "with a body supporting both to_ary and each" do
    let(:fake_body) { double(:each => nil, :to_ary => []) }
    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).to respond_to(:to_ary)
      expect(wrapped).not_to respond_to(:call)
      expect(wrapped).not_to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each" do
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
    end

    it "sets the exception raised inside each() into the Appsignal transaction" do
      expect(fake_body).to receive(:each).once.and_raise(Exception.new("Oops"))

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))

      wrapped = described_class.wrap(fake_body, txn)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(/Oops/)
    end

    it "reads out the body in full using to_ary" do
      expect(fake_body).to receive(:to_ary).and_return(["one", "two", "three"])

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped.to_ary).to eq(["one", "two", "three"])
    end

    it "sends the exception raised inside to_ary() into the Appsignal and closes txn" do
      fake_body = double
      allow(fake_body).to receive(:each)
      expect(fake_body).to receive(:to_ary).once.and_raise(Exception.new("Oops"))
      expect(fake_body).not_to receive(:close) # Per spec we expect the body has closed itself

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))
      expect(Appsignal::Transaction).to receive(:complete_current!).once

      wrapped = described_class.wrap(fake_body, txn)
      expect { wrapped.to_ary }.to raise_error(/Oops/)
    end
  end

  describe "with a body supporting both to_path and each" do
    let(:fake_body) { double(:each => nil, :to_path => nil) }

    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).to respond_to(:each)
      expect(wrapped).not_to respond_to(:to_ary)
      expect(wrapped).not_to respond_to(:call)
      expect(wrapped).to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "reads out the body in full using each()" do
      expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
    end

    it "sets the exception raised inside each() into the Appsignal transaction" do
      expect(fake_body).to receive(:each).once.and_raise(Exception.new("Oops"))

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))

      wrapped = described_class.wrap(fake_body, txn)
      expect do
        expect { |b| wrapped.each(&b) }.to yield_control
      end.to raise_error(/Oops/)
    end

    it "sets the exception raised inside to_path() into the Appsignal transaction" do
      allow(fake_body).to receive(:to_path).once.and_raise(Exception.new("Oops"))

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))
      expect(txn).not_to receive(:complete) # gets called by the caller via close()

      wrapped = described_class.wrap(fake_body, txn)
      expect { wrapped.to_path }.to raise_error(/Oops/)
    end

    it "exposes to_path to the sender" do
      allow(fake_body).to receive(:to_path).and_return("/tmp/file.bin")

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped.to_path).to eq("/tmp/file.bin")
    end
  end

  describe "with a body only supporting call()" do
    let(:fake_body) { double(:call => nil) }
    it "wraps with appropriate class" do
      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect(wrapped).not_to respond_to(:each)
      expect(wrapped).not_to respond_to(:to_ary)
      expect(wrapped).to respond_to(:call)
      expect(wrapped).not_to respond_to(:to_path)
      expect(wrapped).to respond_to(:close)
    end

    it "passes the stream into the call() of the body" do
      fake_rack_stream = double("stream")
      expect(fake_body).to receive(:call).with(fake_rack_stream)

      wrapped = described_class.wrap(fake_body, _txn = nil)
      expect { wrapped.call(fake_rack_stream) }.not_to raise_error
    end

    it "sets the exception raised inside call() into the Appsignal transaction" do
      fake_rack_stream = double
      allow(fake_body).to receive(:call).with(fake_rack_stream).and_raise(Exception.new("Oopsie"))

      txn = double("Appsignal transaction")
      expect(txn).to receive(:set_error).once.with(instance_of(Exception))
      expect(txn).not_to receive(:complete) # gets called by the caller via close()
      wrapped = described_class.wrap(fake_body, txn)

      expect { wrapped.call(fake_rack_stream) }.to raise_error(/Oopsie/)
    end
  end
end
