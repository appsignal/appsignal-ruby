# encoding: UTF-8

describe Appsignal::Utils::Data do
  describe ".generate" do
    subject { Appsignal::Utils::Data.generate(body) }

    context "with a valid hash body" do
      let(:body) do
        {
          "the" => "payload",
          "int" => 1, # Fixnum
          "int61" => 1 << 61, # Fixnum
          "int62" => 1 << 62, # Bignum, this one still works
          "int63" => 1 << 63, # Bignum, turnover point for C, too big for long
          "int64" => 1 << 64, # Bignum
          "float" => 1.0,
          1 => true,
          nil => "test",
          :foo => [1, 2, "three", { "foo" => "bar" }],
          "bar" => nil,
          "baz" => { "foo" => "bʊr", "arr" => [1, 2] }
        }
      end

      it { is_expected.to eq Appsignal::Utils::Data.generate(body) }
      it { is_expected.to_not eq Appsignal::Utils::Data.generate({}) }

      describe "#to_s" do
        it "returns a serialized hash" do
          expect(subject.to_s).to eq %({"":"test",) +
            %("1":true,) +
            %("bar":null,) +
            %("baz":{"arr":[1,2],"foo":"bʊr"},) +
            %("float":1.0,) +
            %("foo":[1,2,"three",{"foo":"bar"}],) +
            %("int":1,) +
            %("int61":#{1 << 61},) +
            %("int62":#{1 << 62},) +
            %("int63":"bigint:#{1 << 63}",) +
            %("int64":"bigint:#{1 << 64}",) +
            %("the":"payload"})
        end
      end
    end

    context "with a valid array body" do
      let(:body) do
        [
          nil,
          true,
          false,
          "string",
          1, # Fixnum
          1.0, # Float
          1 << 61, # Fixnum
          1 << 62, # Bignum, this one still works
          1 << 63, # Bignum, turnover point for C, too big for long
          1 << 64, # Bignum
          { "arr" => [1, 2, "three"], "foo" => "bʊr" }
        ]
      end

      it { is_expected.to eq Appsignal::Utils::Data.generate(body) }
      it { is_expected.to_not eq Appsignal::Utils::Data.generate({}) }

      describe "#to_s" do
        it "returns a serialized array" do
          expect(subject.to_s).to eq %([null,) +
            %(true,) +
            %(false,) +
            %(\"string\",) +
            %(1,) +
            %(1.0,) +
            %(#{1 << 61},) +
            %(#{1 << 62},) +
            %("bigint:#{1 << 63}",) +
            %("bigint:#{1 << 64}",) +
            %({\"arr\":[1,2,\"three\"],\"foo\":\"bʊr\"}])
        end
      end
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

      describe "#to_s" do
        it { expect(subject.to_s).to eq %({"field_four":{"one":"aa�"},"field_one":"aa","field_three":["one","aa�"],"field_two":"aa�"}) }
      end
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
end
