describe Appsignal::Rack::BodyWrapper do
  describe "BodyWrapper" do
    describe "with a body only supporting each()" do
      it "wraps with appropriate class" do
        fake_body = double()
        allow(fake_body).to receive(:each)

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect(wrapped).to respond_to(:each)
        expect(wrapped).not_to respond_to(:to_ary)
        expect(wrapped).not_to respond_to(:call)
        expect(wrapped).not_to respond_to(:call)
        expect(wrapped).to respond_to(:close)
      end

      it "reads out the body in full using each" do
        fake_body = double()
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")
        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "sets the exception raised inside each() into the Appsignal transaction" do
        fake_body = double()
        expect(fake_body).to receive(:each).once.and_raise(Exception.new("Oops"))

        txn = double("Appsignal transaction")
        expect(txn).to receive(:set_error).once.with(instance_of(Exception))

        wrapped = described_class.wrap(fake_body, txn)
        expect { |b| wrapped.each(&b) }.to raise_error(/Oops/)
      end

      it "closes the body and the transaction when it gets closed" do
        fake_body = double()
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        txn = double("Appsignal transaction")
        expect(txn).to receive(:complete).once

        wrapped = described_class.wrap(fake_body, txn)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
        expect { wrapped.close }.not_to raise_error
      end

      it "does not expose to_ary, call and to_path to the sender"
    end

    describe "with a body supporting both each() and call" do
      it "wraps with the wrapper that conceals call() and exposes each" do
        fake_body = double()
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
      it "wraps with appropriate class" do
        fake_body = double()
        allow(fake_body).to receive(:each)
        allow(fake_body).to receive(:to_ary)

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect(wrapped).to respond_to(:each)
        expect(wrapped).to respond_to(:to_ary)
        expect(wrapped).not_to respond_to(:call)
        expect(wrapped).not_to respond_to(:to_path)
        expect(wrapped).to respond_to(:close)
      end

      it "reads out the body in full using each" do
        fake_body = double()
        allow(fake_body).to receive(:to_ary)
        expect(fake_body).to receive(:each).once.and_yield("a").and_yield("b").and_yield("c")

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect { |b| wrapped.each(&b) }.to yield_successive_args("a", "b", "c")
      end

      it "sets the exception raised inside each() into the Appsignal transaction" do
        fake_body = double()
        expect(fake_body).to receive(:each).once.and_raise(Exception.new("Oops"))

        txn = double("Appsignal transaction")
        expect(txn).to receive(:set_error).once.with(instance_of(Exception))

        wrapped = described_class.wrap(fake_body, txn)
        expect { |b| wrapped.each(&b) }.to raise_error(/Oops/)
      end

      it "reads out the body in full using to_ary" do
        fake_body = double()
        allow(fake_body).to receive(:each)
        expect(fake_body).to receive(:to_ary).and_return(["one", "two", "three"])

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect(wrapped.to_ary).to eq(["one", "two", "three"])
      end

      it "sets the exception raised inside to_ary() into the Appsignal transaction and closes the transaction" do
        fake_body = double()
        allow(fake_body).to receive(:each)
        expect(fake_body).to receive(:to_ary).once.and_raise(Exception.new("Oops"))
        expect(fake_body).not_to receive(:close) # We expect the body to close itself inside its implementation of to_ary

        txn = double("Appsignal transaction")
        expect(txn).to receive(:set_error).once.with(instance_of(Exception))
        expect(txn).to receive(:complete).once

        wrapped = described_class.wrap(fake_body, txn)
        expect { wrapped.to_ary }.to raise_error(/Oops/)
      end

      it "closes the body and the transaction when it gets closed, but only once"
      it "exposes to_ary to the sender"
      it "closes itself and the transaction when to_ary is called"
      it "does not try to close the contained body and the transaction when close is called after to_ary"
    end

    describe "with a body supporting both to_path and each" do
      it "wraps with appropriate class" do
        fake_body = double()
        allow(fake_body).to receive(:each)
        allow(fake_body).to receive(:to_path)

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect(wrapped).to respond_to(:each)
        expect(wrapped).not_to respond_to(:to_ary)
        expect(wrapped).not_to respond_to(:call)
        expect(wrapped).to respond_to(:to_path)
        expect(wrapped).to respond_to(:close)
      end

      it "reads out the body in full"
      it "sets the exception raised inside each() into the Appsignal transaction"
      it "sets the exception raised inside to_path() into the Appsignal transaction"
      it "closes the body and the transaction when it gets closed, but only once"
      it "exposes to_path to the sender"
    end

    describe "with a body only supporting call()" do
      it "wraps with appropriate class" do
        fake_body = double()
        allow(fake_body).to receive(:call)

        wrapped = described_class.wrap(fake_body, _txn = nil)
        expect(wrapped).not_to respond_to(:each)
        expect(wrapped).not_to respond_to(:to_ary)
        expect(wrapped).to respond_to(:call)
        expect(wrapped).not_to respond_to(:to_path)
        expect(wrapped).to respond_to(:close)
      end

      it "passes the stream or socket into the call() of the body"
      it "sets the exception raised inside call() into the Appsignal transaction"
      it "closes the body and the transaction when it gets closed, but only once"
    end
  end
end
