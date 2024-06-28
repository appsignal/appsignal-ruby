RSpec.shared_examples "instrument helper" do
  around { |example| keep_transactions { example.run } }
  let(:stub) { double(:method_call => "return value") }

  it "records an event around the given block" do
    return_value = instrumenter.instrument "name", "title", "body" do
      stub.method_call
    end
    expect(return_value).to eq "return value"

    expect_transaction_to_have_event
  end

  context "with an error raised in the passed block" do
    it "records an event around the given block" do
      expect do
        instrumenter.instrument "name", "title", "body" do
          stub.method_call
          raise ExampleException, "foo"
        end
      end.to raise_error(ExampleException, "foo")

      expect_transaction_to_have_event
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

      expect_transaction_to_have_event
    end
  end

  def expect_transaction_to_have_event
    expect(transaction).to include_event(
      "name" => "name",
      "title" => "title",
      "body" => "body",
      "body_format" => Appsignal::EventFormatter::DEFAULT
    )
  end
end
