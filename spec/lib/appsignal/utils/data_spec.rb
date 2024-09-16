describe Appsignal::Utils::Data do
  describe ".generate" do
    def generate(object)
      Appsignal::Utils::Data.generate(object)
    end

    context "when extension is not loaded", :extension_installation_failure do
      around do |example|
        Appsignal::Testing.without_testing { example.run }
      end

      context "with valid hash body" do
        it "does not error and returns MockData class" do
          value = generate(:abc => "def")
          expect(value).to be_kind_of(Appsignal::Extension::MockData)
          expect(value.to_s).to eql("{}")
        end
      end

      context "with valid array body" do
        it "does not error and returns MockData class" do
          value = generate(["abc", "123"])
          expect(value).to be_kind_of(Appsignal::Extension::MockData)
          expect(value.to_s).to eql("{}")
        end
      end

      context "with an invalid body" do
        it "raise a type error" do
          expect do
            generate("body")
          end.to raise_error TypeError
        end
      end
    end

    context "when extension is loaded" do
      context "with a valid hash body" do
        it "returns a valid Data object" do
          value = generate(:abc => "def")
          expect(value).to eq(generate(:abc => "def"))
          expect(value).to_not eq(generate({}))
        end

        describe "#to_s" do
          it "handles empty hashes" do
            expect(generate({}).to_s).to eq(%({}))
          end

          it "handles strings and symbols" do
            expect(generate("abc" => "def").to_s).to eq(%({"abc":"def"}))
            expect(generate(:abc => :def).to_s).to eq(%({"abc":"def"}))
          end

          it "handles Booleans" do
            expect(generate(true => true).to_s).to eq(%({"true":true}))
            expect(generate(false => false).to_s).to eq(%({"false":false}))
          end

          it "handles Integers" do
            expect(generate(123 => "abc").to_s).to eq(%({"123":"abc"}))
            expect(generate("int" => 123_456).to_s).to eq(%({"int":123456}))
          end

          it "handles Floats" do
            expect(generate(12.345 => "abc").to_s).to eq(%({"12.345":"abc"}))
            expect(generate("abc" => 12.345).to_s).to eq(%({"abc":12.345}))
          end

          it "handles empty string keys" do
            expect(generate("" => "abc").to_s).to eq(%({"":"abc"}))
          end

          it "handles nils" do
            expect(generate(nil => "abc").to_s).to eq(%({"":"abc"}))
            expect(generate("abc" => nil).to_s).to eq(%({"abc":null}))
          end

          it "handles bigint numbers" do
            # Fixnum
            expect(generate("int61" => 1 << 61).to_s).to eq(%({"int61":#{1 << 61}}))
            # Bignum, this one still works
            expect(generate("int62" => 1 << 62).to_s).to eq(%({"int62":#{1 << 62}}))
            # Bignum, turnover point for C, too big for long
            expect(generate("int63" => 1 << 63).to_s).to eq(%({"int63":"bigint:#{1 << 63}"}))
            # Bignum
            expect(generate("int64" => 1 << 64).to_s).to eq(%({"int64":"bigint:#{1 << 64}"}))
          end

          it "handles nested Hashes" do
            expect(generate("nested" => { :abc => :def, "hij" => "klm" }).to_s)
              .to eq(%({"nested":{"abc":"def","hij":"klm"}}))
            # Many nested
            expect(generate("a" => { :b => { :c => { :d => :e } } }).to_s)
              .to eq(%({"a":{"b":{"c":{"d":"e"}}}}))
            # Complex nexted
            expect(generate("a" => { :b => 123, :c => 12.34, :d => nil }).to_s)
              .to eq(%({"a":{"b":123,"c":12.34,"d":null}}))
          end

          it "handles nested array values" do
            expect(generate("a" => ["abc", 123]).to_s).to eq(%({"a":["abc",123]}))
            # Many nested
            expect(generate("a" => ["abc", [:def]]).to_s).to eq(%({"a":["abc",["def"]]}))
            # Nested Hash
            expect(generate("a" => ["b" => "c"]).to_s).to eq(%({"a":[{"b":"c"}]}))
          end

          it "casts unsupported key types to string" do
            expect(generate([1, 2] => "abc").to_s).to eq(%({"[1, 2]":"abc"}))
            expect(generate({ :a => "b" } => "abc").to_s).to eq(%({"{:a=>\\"b\\"}":"abc"}))
          end
        end
      end

      context "with a valid array body" do
        it "returns a valid Data object" do
          expect(generate(["abc", "def"])).to eq(generate(["abc", "def"]))
          expect(generate(["abc", "def"])).to_not eq(generate({}))
        end

        describe "#to_s" do
          it "handles empty arrays" do
            expect(generate([]).to_s).to eq(%([]))
          end

          it "handles strings and symbols" do
            expect(generate(["abc", "def"]).to_s).to eq(%(["abc","def"]))
            expect(generate([:abc, :def]).to_s).to eq(%(["abc","def"]))
          end

          it "handles Booleans" do
            expect(generate([true, false]).to_s).to eq(%([true,false]))
          end

          it "handles Integers" do
            expect(generate([123, 123_456]).to_s).to eq(%([123,123456]))
          end

          it "handles Floats" do
            expect(generate([123.456, 456.789]).to_s).to eq(%([123.456,456.789]))
          end

          it "handles nils" do
            expect(generate(["abc", nil]).to_s).to eq(%(["abc",null]))
          end

          it "handles bigint numbers" do
            # Fixnum
            expect(generate([1 << 61]).to_s).to eq(%([#{1 << 61}]))
            # Bignum, this one still works
            expect(generate([1 << 62]).to_s).to eq(%([#{1 << 62}]))
            # Bignum, turnover point for C, too big for long
            expect(generate([1 << 63]).to_s).to eq(%(["bigint:#{1 << 63}"]))
            # Bignum
            expect(generate([1 << 64]).to_s).to eq(%(["bigint:#{1 << 64}"]))
          end

          it "handles nested Hashes" do
            expect(generate(["a", { :abc => :def, "hij" => "klm" }]).to_s)
              .to eq(%(["a",{"abc":"def","hij":"klm"}]))
            # Many nested
            expect(generate(["a", { :b => { :c => { :d => :e } } }]).to_s)
              .to eq(%(["a",{"b":{"c":{"d":"e"}}}]))
            # Complex nexted
            expect(generate(["a", { :b => [123], :c => 12.34, :d => nil }]).to_s)
              .to eq(%(["a",{"b":[123],"c":12.34,"d":null}]))
          end

          it "handles nested array values" do
            expect(generate([123, [456, [789]]]).to_s).to eq(%([123,[456,[789]]]))
          end
        end
      end

      context "with a body that contains strings with invalid utf-8 content" do
        describe "#to_s" do
          it "returns a JSON representation in a String" do
            string_with_invalid_utf8 = [0x61, 0x61, 0x85].pack("c*")
            value = {
              "field_one" => [0x61, 0x61].pack("c*"),
              :field_two => string_with_invalid_utf8,
              "field_three" => [
                "one", string_with_invalid_utf8
              ],
              "field_four" => {
                "one" => string_with_invalid_utf8
              }
            }
            # rubocop:disable Style/StringConcatenation
            expect(generate(value).to_s).to eq %({"field_four":{"one":"aa�"},) +
              %("field_one":"aa",) +
              %("field_three":["one","aa�"],) +
              %("field_two":"aa�"})
            # rubocop:enable Style/StringConcatenation
          end
        end
      end

      context "with an invalid body" do
        it "raises a type error" do
          expect do
            generate("body")
          end.to raise_error TypeError
        end
      end
    end
  end
end
