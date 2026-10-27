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

    context "with a body that contains binary strings" do
      let(:body) do
        {
          "utf8" => "café 日本".b,
          "latin1" => "caf\xE9".b,
          "frozen" => "café".b.freeze
        }
      end

      it "returns a JSON string with the strings read as UTF-8" do
        is_expected.to eq '{"utf8":"café 日本","latin1":"caf�","frozen":"café"}'
      end
    end

    context "with a body that contains NaN and Infinity" do
      let(:body) do
        {
          "nan" => Float::NAN,
          "infinity" => Float::INFINITY,
          "negative_infinity" => -Float::INFINITY,
          "float" => 1.5,
          "list" => [Float::NAN, Float::INFINITY, -Float::INFINITY]
        }
      end

      it "returns a JSON string with NaN and Infinity as strings" do
        is_expected.to eq '{"nan":"NaN","infinity":"Infinity",' \
          '"negative_infinity":"-Infinity","float":1.5,' \
          '"list":["NaN","Infinity","-Infinity"]}'
      end
    end

    describe "nesting" do
      let(:max_depth_message) do
        "Data is nested more than 100 levels deep. " \
          "Deeper values are replaced with '[MAX DEPTH REACHED]'."
      end

      context "with a body nested 100 levels deep" do
        let(:body) { nested_arrays(100) }

        it "returns the complete JSON string" do
          logs = capture_logs { is_expected.to eq(("[" * 100) + ("]" * 100)) }

          expect(logs).to_not contains_log :error, max_depth_message
        end
      end

      context "with a body nested more than 100 levels deep" do
        let(:body) { nested_arrays(101) }

        it "replaces the deeper values with a placeholder" do
          logs = capture_logs do
            is_expected.to eq(%(#{"[" * 100}"[MAX DEPTH REACHED]"#{"]" * 100}))
          end

          expect(logs).to contains_log :error, max_depth_message
        end
      end

      context "with a body that contains itself" do
        let(:body) { [].tap { |array| array << array } }

        it "replaces the values past the limit with a placeholder" do
          logs = capture_logs do
            is_expected.to eq("#{"[" * 100}\"[MAX DEPTH REACHED]\"#{"]" * 100}")
          end

          expect(logs).to contains_log :error, max_depth_message
        end
      end

      context "with a body that reaches the limit more than once" do
        let(:body) { { "one" => nested_arrays(101), "two" => nested_arrays(101) } }

        it "logs the message only once" do
          logs = capture_logs { subject }

          expect(logs.scan(max_depth_message).length).to eq(1)
        end
      end

      def nested_arrays(levels)
        root = []
        current = root
        (levels - 1).times do
          child = []
          current << child
          current = child
        end
        root
      end
    end

    context "with a body that contains a value whose to_s raises" do
      before do
        stub_const("Money", Class.new do
          def to_s
            raise "boom"
          end
        end)
      end

      let(:body) { { "price" => Money.new, "list" => [Money.new] } }

      it "replaces the value with a placeholder and logs an error" do
        logs = capture_logs do
          is_expected.to eq '{"price":"[UNSERIALIZABLE VALUE]",' \
            '"list":["[UNSERIALIZABLE VALUE]"]}'
        end

        expect(logs).to contains_log :error,
          "Unable to serialize value: #<Money: to_s raised RuntimeError: boom>"
      end
    end
  end
end
