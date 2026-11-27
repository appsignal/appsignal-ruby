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

    context "with a string in an encoding that can't be converted to UTF-8" do
      it "reads its bytes as UTF-8" do
        result = encode("abc".dup.force_encoding(Encoding::UTF_7))

        expect(result).to eq("abc")
        expect(result.encoding).to eq(Encoding::UTF_8)
      end
    end

    context "with a value that is not a String" do
      it "returns the value itself" do
        [nil, :symbol, 1, 1.5, true, ["caf\xE9".b]].each do |value|
          expect(encode(value)).to equal(value)
        end
      end
    end
  end

  describe ".encode_hash" do
    let(:invalid) { "caf\xE9".dup.force_encoding(Encoding::UTF_8) }
    let(:replaced) { "caf\u{FFFD}" }

    it "converts the keys and values" do
      expect(described_class.encode_hash(invalid => invalid, :key => 1))
        .to eq(replaced => replaced, :key => 1)
    end

    it "does not convert nested values" do
      nested = { "key" => [invalid] }

      expect(described_class.encode_hash(nested)["key"]).to equal(nested["key"])
    end

    it "does not change the given Hash" do
      hash = { invalid => invalid }
      described_class.encode_hash(hash)

      expect(hash.keys.first.bytes).to eq([99, 97, 102, 233])
    end

    it "returns a value that is not a Hash as it is" do
      expect(described_class.encode_hash(nil)).to be_nil
    end
  end
end
