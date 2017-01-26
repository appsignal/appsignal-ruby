describe Appsignal::JSExceptionTransaction do
  before { allow(SecureRandom).to receive(:uuid).and_return("123abc") }

  let!(:transaction) { Appsignal::JSExceptionTransaction.new(data) }
  let(:data) do
    {
      "name"        => "TypeError",
      "message"     => "foo is not a valid method",
      "action"      => "ExceptionIncidentComponent",
      "path"        => "foo.bar/moo",
      "environment" => "development",
      "backtrace"   => [
        "foo.bar/js:11:1",
        "foo.bar/js:22:2"
      ],
      "tags" => [
        "tag1"
      ]
    }
  end

  describe "#initialize" do
    it "should call all required methods" do
      expect(Appsignal::Extension).to receive(:start_transaction).with("123abc", "frontend", 0).and_return(1)

      expect(transaction).to receive(:set_action)
      expect(transaction).to receive(:set_metadata)
      expect(transaction).to receive(:set_error)
      expect(transaction).to receive(:set_sample_data)

      transaction.send :initialize, data

      expect(transaction.ext).to_not be_nil
    end
  end

  describe "#set_action" do
    it "should call `Appsignal::Extension.set_action`" do
      expect(transaction.ext).to receive(:set_action).with(
        "ExceptionIncidentComponent"
      )

      transaction.set_action
    end
  end

  describe "#set_metadata" do
    it "should call `Appsignal::Extension.set_transaction_metadata`" do
      expect(transaction.ext).to receive(:set_metadata).with(
        "path",
        "foo.bar/moo"
      )

      transaction.set_metadata
    end
  end

  describe "#set_error" do
    it "should call `Appsignal::Extension.set_transaction_error`" do
      expect(transaction.ext).to receive(:set_error).with(
        "TypeError",
        "foo is not a valid method",
        Appsignal::Utils.data_generate(["foo.bar/js:11:1", "foo.bar/js:22:2"])
      )

      transaction.set_error
    end
  end

  describe "#set_sample_data" do
    it "should call `Appsignal::Extension.set_transaction_error_data`" do
      expect(transaction.ext).to receive(:set_sample_data).with(
        "tags",
        Appsignal::Utils.data_generate(["tag1"])
      )

      transaction.set_sample_data
    end
  end

  context "when sending just the name" do
    let(:data) { { "name" => "TypeError" } }

    describe "#set_action" do
      it "should not call `Appsignal::Extension.set_action`" do
        expect(transaction.ext).to_not receive(:set_action)

        transaction.set_action
      end
    end

    describe "#set_metadata" do
      it "should not call `Appsignal::Extension.set_transaction_metadata`" do
        expect(transaction.ext).to_not receive(:set_metadata)

        transaction.set_metadata
      end
    end

    describe "#set_error" do
      it "should call `Appsignal::Extension.set_transaction_error` with just the name" do
        expect(transaction.ext).to receive(:set_error).with(
          "TypeError",
          "",
          Appsignal::Utils.data_generate([])
        )

        transaction.set_error
      end
    end

    describe "#set_sample_data" do
      it "should not call `Appsignal::Extension.set_transaction_error_data`" do
        expect(transaction.ext).to_not receive(:set_sample_data)

        transaction.set_sample_data
      end
    end
  end

  describe "#complete!" do
    it "should call all required methods" do
      expect(transaction.ext).to receive(:finish).and_call_original
      expect(transaction.ext).to receive(:complete).and_call_original
      transaction.complete!
    end
  end
end
