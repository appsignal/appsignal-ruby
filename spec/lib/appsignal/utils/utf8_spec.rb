describe Appsignal::Utils::UTF8 do
  describe ".encode" do
    def encode(string)
      described_class.encode(string)
    end

    context "with a valid UTF-8 string" do
      it "returns the string itself" do
        string = "café 日本"

        expect(encode(string)).to equal(string)
      end
    end

    context "with a UTF-8 string with invalid bytes" do
      let(:string) { "caf\xE9".dup.force_encoding(Encoding::UTF_8) }

      it "replaces the invalid bytes" do
        result = encode(string)

        expect(result).to eq("caf\u{FFFD}")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "does not change the given string" do
        encode(string)

        expect(string.bytes).to eq([99, 97, 102, 233])
      end
    end

    context "with a binary string" do
      it "reads bytes that are valid UTF-8 as UTF-8" do
        result = encode("café 日本".b)

        expect(result).to eq("café 日本")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "replaces the bytes that are not valid UTF-8" do
        expect(encode("caf\xE9".b)).to eq("caf\u{FFFD}")
      end

      it "converts an ASCII-only string" do
        result = encode("abc".b)

        expect(result).to eq("abc")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "converts a frozen string" do
        expect(encode("café".b.freeze)).to eq("café")
      end
    end

    context "with a string in another encoding" do
      it "converts it to UTF-8" do
        result = encode("café".encode(Encoding::ISO_8859_1))

        expect(result).to eq("café")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end

      it "converts an ASCII-only string to UTF-8" do
        result = encode(1.to_s)

        expect(result).to eq("1")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
