RSpec.shared_examples "instrument helper" do
  let(:stub) { double }
  before do
    expect(stub).to receive(:method_call).and_return("return value")

    expect(transaction).to receive(:start_event)
    expect(transaction).to receive(:finish_event).with(
      "name",
      "title",
      "body",
      0
    )
  end

  it "records an event around the given block" do
    return_value = instrumenter.instrument "name", "title", "body" do
      stub.method_call
    end
    expect(return_value).to eq "return value"
  end

  context "with an error raised in the passed block" do
    it "records an event around the given block" do
      expect do
        instrumenter.instrument "name", "title", "body" do
          stub.method_call
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")
    end
  end

  context "with an error raise in the passed block" do
    it "records an event around the given block" do
      expect do
        instrumenter.instrument "name", "title", "body" do
          stub.method_call
          throw :foo
        end
      end.to throw_symbol(:foo)
    end
  end
end
