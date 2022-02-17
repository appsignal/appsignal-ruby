describe Appsignal::Utils::QueryParamsSanitizer do
  describe ".sanitize" do
    context "when only_top_level = true" do
      subject { described_class.sanitize(value, true) }

      context "when value is a hash" do
        let(:value) { { "foo" => "bar" } }

        it "should only return the first level of the object" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => "bar")
        end
      end

      context "when value is a nested hash" do
        let(:value) { { "foo" => { "bar" => "baz" } } }

        it "should only return the first level of the object" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => { "bar" => "baz" })
        end
      end

      context "when value is an array of hashes" do
        let(:value) { ["foo" => "bar"] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq(["foo" => "?"])
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(["foo" => "bar"])
        end
      end

      context "when value is an array" do
        let(:value) { %w[foo bar] }

        it "sanitizes all array values" do
          expect(subject).to eq(["?"])
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(%w[foo bar])
        end
      end

      context "when value is a mixed array" do
        let(:value) { [nil, "foo", "bar"] }

        it "should sanitize all array values with a single questionmark" do
          expect(subject).to eq(["?"])
        end
      end

      context "when value is a string" do
        let(:value) { "foo" }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("?")
        end
      end
    end

    context "when only_top_level = false" do
      subject { described_class.sanitize(value, false) }

      context "when value is a hash" do
        let(:value) { { "foo" => "bar" } }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("foo" => "?")
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => "bar")
        end
      end

      context "when value is a nested hash" do
        let(:value) { { "foo" => { "bar" => "baz" } } }

        it "should replaces values" do
          expect(subject).to eq("foo" => { "bar" => "?" })
        end

        it "should not modify source value" do
          subject
          expect(value).to eq("foo" => { "bar" => "baz" })
        end
      end

      context "when value is an array of hashes" do
        let(:value) { ["foo" => "bar"] }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq(["foo" => "?"])
        end

        it "should not modify source value" do
          subject
          expect(value).to eq(["foo" => "bar"])
        end
      end

      context "when value is an array" do
        let(:value) { %w[foo bar] }

        it "should sanitize all hash values with a single question mark" do
          expect(subject).to eq(["?"])
        end
      end

      context "when value is a mixed array" do
        let(:value) { [nil, "foo", "bar"] }

        it "should sanitize all hash values with a single question mark" do
          expect(subject).to eq(["?"])
        end
      end

      context "when value is a string" do
        let(:value) { "bar" }

        it "should sanitize all hash values with a questionmark" do
          expect(subject).to eq("?")
        end
      end
    end
  end

  describe "key_sanitizer option" do
    context "without key_sanitizer" do
      subject { described_class.sanitize(value) }

      context "when dots are in the key" do
        let(:value) { { "foo.bar" => "bar" } }

        it "should not sanitize the key" do
          expect(subject).to eql("foo.bar" => "?")
        end
      end

      context "when key is a symbol" do
        let(:value) { { :ismaster => "bar" } }

        it "should sanitize the key" do
          expect(subject).to eql(:ismaster => "?")
        end
      end
    end

    context "with mongodb key_sanitizer" do
      subject { described_class.sanitize(value, false, :mongodb) }

      context "when no dots are in the key" do
        let(:value) { { "foo" => "bar" } }

        it "should not sanitize the key" do
          expect(subject).to eql("foo" => "?")
        end
      end

      context "when dots are in the key" do
        let(:value) { { "foo.bar" => "bar" } }

        it "should sanitize the key" do
          expect(subject).to eql("foo.?" => "?")
        end
      end

      context "when key is a symbol" do
        let(:value) { { :ismaster => "bar" } }

        it "should sanitize the key" do
          expect(subject).to eql("ismaster" => "?")
        end
      end
    end
  end
end
