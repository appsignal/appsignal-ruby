describe Appsignal::Utils::HashSanitizer do
  let(:file) { uploaded_file }
  let(:params) do
    {
      :text => "string",
      "string" => "string key value",
      :file => file,
      :float => 0.0,
      :bool_true => true,
      :bool_false => false,
      :nil => nil,
      :int => 1, # Fixnum
      :int64 => 1 << 64, # Bignum
      :hash => {
        :nested_text => "string",
        :nested_array => [
          "something",
          "else",
          file,
          {
            :key => "value",
            :file => file
          }
        ]
      }
    }
  end

  describe ".sanitize" do
    let(:sanitized_params) { described_class.sanitize(params) }
    subject { sanitized_params }

    it "returns a sanitized Hash" do
      expect(subject).to_not eq(params)
      is_expected.to be_instance_of Hash
      expect(subject[:text]).to eq("string")
      expect(subject["string"]).to eq("string key value")
      expect(subject[:file]).to be_instance_of String
      expect(subject[:file]).to include "::UploadedFile"
      expect(subject[:float]).to eq(0.0)
      expect(subject[:bool_true]).to be(true)
      expect(subject[:bool_false]).to be(false)
      expect(subject[:nil]).to be_nil
      expect(subject[:int]).to eq(1)
      expect(subject[:int64]).to eq(1 << 64)
    end

    it "does not change the original params" do
      subject
      expect(params[:file]).to eq(file)
      expect(params[:hash][:nested_array][2]).to eq(file)
    end

    describe ":hash key" do
      subject { sanitized_params[:hash] }

      it "returns a sanitized Hash" do
        expect(subject).to_not eq(params[:hash])
        is_expected.to be_instance_of Hash
        expect(subject[:nested_text]).to eq("string")
      end

      describe ":nested_array key" do
        subject { sanitized_params[:hash][:nested_array] }

        it "returns a sanitized Array" do
          expect(subject).to_not eq(params[:hash][:nested_array])
          is_expected.to be_instance_of Array
          expect(subject[0]).to eq("something")
          expect(subject[1]).to eq("else")
          expect(subject[2]).to be_instance_of String
          expect(subject[2]).to include "::UploadedFile"
        end

        describe ":nested_hash key" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it "returns a sanitized Hash" do
            expect(subject).to_not eq(params[:hash][:nested_array][3])
            is_expected.to be_instance_of Hash
            expect(subject[:key]).to eq("value")
            expect(subject[:file]).to be_instance_of String
            expect(subject[:file]).to include "::UploadedFile"
          end
        end
      end
    end

    context "with filter_keys" do
      let(:sanitized_params) do
        described_class.sanitize(params, %w[text hash])
      end
      subject { sanitized_params }

      it "returns a sanitized Hash with the given keys filtered out" do
        expect(subject).to_not eq(params)
        expect(subject[:text]).to eq(described_class::FILTERED)
        expect(subject[:hash]).to eq(described_class::FILTERED)

        expect(subject[:file]).to be_instance_of String
        expect(subject[:file]).to include "::UploadedFile"
        expect(subject[:float]).to eq(0.0)
        expect(subject[:bool_true]).to be(true)
        expect(subject[:bool_false]).to be(false)
        expect(subject[:nil]).to be_nil
        expect(subject[:int]).to eq(1)
      end

      context "with strings as key filter values" do
        let(:sanitized_params) do
          described_class.sanitize(params, %w[string])
        end

        it "sanitizes values" do
          expect(subject["string"]).to eq("[FILTERED]")
        end
      end

      describe ":hash key" do
        let(:sanitized_params) do
          described_class.sanitize(params, %w[nested_text])
        end
        subject { sanitized_params[:hash] }

        it "sanitizes values in nested hashes" do
          expect(subject[:nested_text]).to eq("[FILTERED]")
        end

        describe ":nested_array" do
          describe ":nested_hash" do
            let(:sanitized_params) do
              described_class.sanitize(params, %w[key])
            end
            subject { sanitized_params[:hash][:nested_array][3] }

            it "sanitizes values in deeply nested hashes and arrays" do
              expect(subject[:key]).to eq("[FILTERED]")
            end
          end
        end
      end
    end
  end
end
