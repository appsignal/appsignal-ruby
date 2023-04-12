describe Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter do
  let(:formatter) { Appsignal::EventFormatter::MongoRubyDriver::QueryFormatter }

  describe ".format" do
    let(:strategy) { :find }
    let(:command) do
      {
        "find" => "users",
        "filter" => { "_id" => 1 }
      }
    end

    it "should apply a strategy for each key" do
      # TODO: additional curly brackets required for issue
      # https://github.com/rspec/rspec-mocks/issues/1460
      expect(formatter).to receive(:apply_strategy)
        .with(:sanitize_document, { "_id" => 1 })
      expect(formatter).to receive(:apply_strategy)
        .with(:allow, "users")

      formatter.format(strategy, command)
    end

    context "when strategy is unkown" do
      let(:strategy) { :bananas }

      it "should return an empty hash" do
        expect(formatter.format(strategy, command)).to eql({})
      end
    end

    context "when command is not a hash " do
      let(:command) { :bananas }

      it "should return an empty hash" do
        expect(formatter.format(strategy, command)).to eql({})
      end
    end
  end

  describe ".apply_strategy" do
    context "when strategy is allow" do
      let(:strategy) { :allow }
      let(:value)    { { "_id" => 1 } }

      it "should return the given value" do
        expect(formatter.apply_strategy(strategy, value)).to eql(value)
      end
    end

    context "when strategy is sanitize_document" do
      let(:strategy) { :sanitize_document }
      let(:value) do
        {
          "_id" => 1,
          "authors" => [
            { "name" => "BarBaz" },
            { "name" => "FooBar" },
            { "name" => "BarFoo", "surname" => "Baz" }
          ]
        }
      end

      it "should return a sanitized document" do
        expect(formatter.apply_strategy(strategy, value)).to eql(
          "_id" => "?",
          "authors" => [
            { "name" => "?" },
            { "name" => "?", "surname" => "?" }
          ]
        )
      end
    end

    context "when strategy is missing" do
      let(:strategy) { nil }
      let(:value)    { { "_id" => 1 } }

      it "should return a '?'" do
        expect(formatter.apply_strategy(strategy, value)).to eql("?")
      end
    end
  end
end
