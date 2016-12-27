# encoding: UTF-8

describe Appsignal::Utils do
  describe ".data_generate" do
    subject { Appsignal::Utils.data_generate(body) }

    context "with a valid hash body" do
      let(:body) do
        {
          "the" => "payload",
          "int" => 1,
          "float" => 1.0,
          1 => true,
          nil => "test",
          :foo => [1, 2, "three", { "foo" => "bar" }],
          "bar" => nil,
          "baz" => { "foo" => "bʊr", "arr" => [1, 2] }
        }
      end

      it { should eq Appsignal::Utils.data_generate(body) }
      it { should_not eq Appsignal::Utils.data_generate({}) }
      it { should_not eq "a string" }
      its(:to_s) { should eq %({"":"test","1":true,"bar":null,"baz":{"arr":[1,2],"foo":"bʊr"},"float":1.0,"foo":[1,2,"three",{"foo":"bar"}],"int":1,"the":"payload"}) }
    end

    context "with a valid array body" do
      let(:body) do
        [1, "string", 10, { "foo" => "bʊr" }]
      end

      its(:to_s) { should eq %([1,\"string\",10,{\"foo\":\"bʊr\"}]) }
    end

    context "with a body that contains strings with invalid utf-8 content" do
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

      its(:to_s) { should eq %({"field_four":{"one":"aa�"},"field_one":"aa","field_three":["one","aa�"],"field_two":"aa�"}) }
    end

    context "with an invalid body" do
      let(:body) { "body" }

      it "should raise a type error" do
        expect do
          subject
        end.to raise_error TypeError
      end
    end
  end

  describe ".json_generate" do
    subject { Appsignal::Utils.json_generate(body) }

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

      it { should eq %({"the":"payload","1":true,"":"test","foo":[1,2,"three"],"bar":null,"baz":{"foo":"bar"}}) }
    end

    context "with a body that contains strings with invalid utf-8 content" do
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

      it { should eq %({"field_one":"aa","field_two":"aa�","field_three":["one","aa�"],"field_four":{"one":"aa�"}}) }
    end
  end
end
