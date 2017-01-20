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
      :int        => 1,
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

    describe '[:text]' do
      subject { super()[:text] }
      it { is_expected.to eq("string") }
    end

    describe "[\"string\"]" do
      subject { super()["string"] }
      it { is_expected.to eq("string key value") }
    end

    describe '[:file]' do
      subject { super()[:file] }
      it { is_expected.to be_instance_of String }
    end

    describe '[:file]' do
      subject { super()[:file] }
      it { is_expected.to include "::UploadedFile" }
    end

    describe '[:float]' do
      subject { super()[:float] }
      it { is_expected.to eq(0.0) }
    end

    describe '[:bool_true]' do
      subject { super()[:bool_true] }
      it { is_expected.to be(true) }
    end

    describe '[:bool_false]' do
      subject { super()[:bool_false] }
      it { is_expected.to be(false) }
    end

    describe '[:nil]' do
      subject { super()[:nil] }
      it { is_expected.to be_nil }
    end

    describe '[:int]' do
      subject { super()[:int] }
      it { is_expected.to eq(1) }
    end

    it "does not change the original params" do
      subject
      expect(params[:file]).to eq(file)
      expect(params[:hash][:nested_array][2]).to eq(file)
    end

    describe ":hash" do
      subject { sanitized_params[:hash] }

      it { is_expected.to be_instance_of Hash }

      describe '[:nested_text]' do
        subject { super()[:nested_text] }
        it { is_expected.to eq("string") }
      end

      describe ":nested_array" do
        subject { sanitized_params[:hash][:nested_array] }

        it { is_expected.to be_instance_of Array }

        describe '[0]' do
          subject { super()[0] }
          it { is_expected.to eq("something") }
        end

        describe '[1]' do
          subject { super()[1] }
          it { is_expected.to eq("else") }
        end

        describe '[2]' do
          subject { super()[2] }
          it { is_expected.to be_instance_of String }
        end

        describe '[2]' do
          subject { super()[2] }
          it { is_expected.to include "::UploadedFile" }
        end

        describe ":nested_hash" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it { is_expected.to be_instance_of Hash }

          describe '[:key]' do
            subject { super()[:key] }
            it { is_expected.to eq("value") }
          end

          describe '[:file]' do
            subject { super()[:file] }
            it { is_expected.to be_instance_of String }
          end

          describe '[:file]' do
            subject { super()[:file] }
            it { is_expected.to include "::UploadedFile" }
          end
        end
      end
    end

    context "with :filter_parameters option" do
      let(:sanitized_params) do
        described_class.sanitize(params, :filter_parameters => %w(text hash))
      end
      subject { sanitized_params }

      describe '[:text]' do
        subject { super()[:text] }
        it { is_expected.to eq(described_class::FILTERED) }
      end

      describe '[:hash]' do
        subject { super()[:hash] }
        it { is_expected.to eq(described_class::FILTERED) }
      end

      describe '[:file]' do
        subject { super()[:file] }
        it { is_expected.to be_instance_of String }
      end

      describe '[:file]' do
        subject { super()[:file] }
        it { is_expected.to include "::UploadedFile" }
      end

      describe '[:float]' do
        subject { super()[:float] }
        it { is_expected.to eq(0.0) }
      end

      describe '[:bool_true]' do
        subject { super()[:bool_true] }
        it { is_expected.to be(true) }
      end

      describe '[:bool_false]' do
        subject { super()[:bool_false] }
        it { is_expected.to be(false) }
      end

      describe '[:nil]' do
        subject { super()[:nil] }
        it { is_expected.to be_nil }
      end

      describe '[:int]' do
        subject { super()[:int] }
        it { is_expected.to eq(1) }
      end

      context "with strings as key filter values" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(string))
        end

        describe "[\"string\"]" do
          subject { super()["string"] }
          it { is_expected.to eq("[FILTERED]") }
        end
      end

      describe ":hash" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(nested_text))
        end
        subject { sanitized_params[:hash] }

        describe '[:nested_text]' do
          subject { super()[:nested_text] }
          it { is_expected.to eq("[FILTERED]") }
        end

        describe ":nested_array" do
          describe ":nested_hash" do
            let(:sanitized_params) do
              described_class.sanitize(params, :filter_parameters => %w(key))
            end
            subject { sanitized_params[:hash][:nested_array][3] }

            describe '[:key]' do
              subject { super()[:key] }
              it { is_expected.to eq("[FILTERED]") }
            end
          end
        end
      end
    end
  end
end
