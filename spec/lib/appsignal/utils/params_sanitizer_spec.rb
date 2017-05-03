describe Appsignal::Utils::ParamsSanitizer do
  let(:file) { uploaded_file }
  let(:params) do
    {
      :text       => "string",
      "string"    => "string key value",
      :file       => file,
      :float      => 0.0,
      :bool_true  => true,
      :bool_false => false,
      :nil        => nil,
      :int        => 1, # Fixnum
      :int64      => 1 << 64, # Bignum
      :hash       => {
        :nested_text  => "string",
        :nested_array => [
          "something",
          "else",
          file,
          {
            :key  => "value",
            :file => file
          }
        ]
      }
    }
  end

  describe ".sanitize" do
    let(:sanitized_params) { described_class.sanitize(params) }
    subject { sanitized_params }

    it { is_expected.to be_instance_of Hash }
    it { expect(subject[:text]).to eq("string") }
    it { expect(subject["string"]).to eq("string key value") }
    it do
      expect(subject[:file]).to be_instance_of String
      expect(subject[:file]).to include "::UploadedFile"
    end
    it { expect(subject[:float]).to eq(0.0) }
    it { expect(subject[:bool_true]).to be(true) }
    it { expect(subject[:bool_false]).to be(false) }
    it { expect(subject[:nil]).to be_nil }
    it { expect(subject[:int]).to eq(1) }
    it { expect(subject[:int64]).to eq(1 << 64) }

    it "does not change the original params" do
      subject
      expect(params[:file]).to eq(file)
      expect(params[:hash][:nested_array][2]).to eq(file)
    end

    describe ":hash" do
      subject { sanitized_params[:hash] }

      it { is_expected.to be_instance_of Hash }
      it { expect(subject[:nested_text]).to eq("string") }

      describe ":nested_array" do
        subject { sanitized_params[:hash][:nested_array] }

        it { is_expected.to be_instance_of Array }
        it { expect(subject[0]).to eq("something") }
        it { expect(subject[1]).to eq("else") }
        it do
          expect(subject[2]).to be_instance_of String
          expect(subject[2]).to include "::UploadedFile"
        end

        describe ":nested_hash" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it { is_expected.to be_instance_of Hash }
          it { expect(subject[:key]).to eq("value") }
          it do
            expect(subject[:file]).to be_instance_of String
            expect(subject[:file]).to include "::UploadedFile"
          end
        end
      end
    end

    context "with :filter_parameters option" do
      let(:sanitized_params) do
        described_class.sanitize(params, :filter_parameters => %w(text hash))
      end
      subject { sanitized_params }

      it { expect(subject[:text]).to eq(described_class::FILTERED) }
      it { expect(subject[:hash]).to eq(described_class::FILTERED) }
      it do
        expect(subject[:file]).to be_instance_of String
        expect(subject[:file]).to include "::UploadedFile"
      end
      it { expect(subject[:float]).to eq(0.0) }
      it { expect(subject[:bool_true]).to be(true) }
      it { expect(subject[:bool_false]).to be(false) }
      it { expect(subject[:nil]).to be_nil }
      it { expect(subject[:int]).to eq(1) }

      context "with strings as key filter values" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(string))
        end

        it "sanitizes values" do
          expect(subject["string"]).to eq("[FILTERED]")
        end
      end

      describe ":hash" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(nested_text))
        end
        subject { sanitized_params[:hash] }

        it "sanitizes values in nested hashes" do
          expect(subject[:nested_text]).to eq("[FILTERED]")
        end

        describe ":nested_array" do
          describe ":nested_hash" do
            let(:sanitized_params) do
              described_class.sanitize(params, :filter_parameters => %w(key))
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
