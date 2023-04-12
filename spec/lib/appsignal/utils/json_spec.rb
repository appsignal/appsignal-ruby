describe Appsignal::Utils::JSON do
  describe ".generate" do
    subject { Appsignal::Utils::JSON.generate(body) }

    context "with a valid body" do
      let(:body) do
        {
          "the" => "payload",
          1 => true,
          nil => "test",
          :foo => [1, 2, "three"],
          "bar" => nil,
          "baz" => { "foo" => "bar" }
        }
      end

      it "returns a JSON string" do
        is_expected.to eq %({"the":"payload","1":true,"":"test",) +
          %("foo":[1,2,"three"],"bar":null,"baz":{"foo":"bar"}})
      end
    end

    context "with a body that contains strings with invalid UTF-8 content" do
      let(:string_with_invalid_utf8) { [0x61, 0x61, 0x85].pack("c*") }
      let(:body) do
        {
          "field_one" => [0x61, 0x61].pack("c*"),
          :field_two => string_with_invalid_utf8,
          "field_three" => [
            "one", string_with_invalid_utf8
          ],
          "field_four" => {
            "one" => string_with_invalid_utf8
          }
        }
      end

      it "returns a JSON string with invalid UTF-8 content" do
        is_expected.to eq %({"field_one":"aa","field_two":"aa�",) +
          %("field_three":["one","aa�"],"field_four":{"one":"aa�"}})
      end
    end
  end
end
