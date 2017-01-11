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

    it { should be_instance_of Hash }
    its([:text]) { should eq("string") }
    its(["string"]) { should eq("string key value") }
    its([:file]) { should be_instance_of String }
    its([:file]) { should include "::UploadedFile" }
    its([:float]) { should eq(0.0) }
    its([:bool_true]) { should be(true) }
    its([:bool_false]) { should be(false) }
    its([:nil]) { should be_nil }
    its([:int]) { should eq(1) }

    it "does not change the original params" do
      subject
      params[:file].should eq(file)
      params[:hash][:nested_array][2].should eq(file)
    end

    describe ":hash" do
      subject { sanitized_params[:hash] }

      it { should be_instance_of Hash }
      its([:nested_text]) { should eq("string") }

      describe ":nested_array" do
        subject { sanitized_params[:hash][:nested_array] }

        it { should be_instance_of Array }
        its([0]) { should eq("something") }
        its([1]) { should eq("else") }
        its([2]) { should be_instance_of String }
        its([2]) { should include "::UploadedFile" }

        describe ":nested_hash" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should eq("value") }
          its([:file]) { should be_instance_of String }
          its([:file]) { should include "::UploadedFile" }
        end
      end
    end

    context "with :filter_parameters option" do
      let(:sanitized_params) do
        described_class.sanitize(params, :filter_parameters => %w(text hash))
      end
      subject { sanitized_params }

      its([:text]) { should eq(described_class::FILTERED) }
      its([:hash]) { should eq(described_class::FILTERED) }
      its([:file]) { should be_instance_of String }
      its([:file]) { should include "::UploadedFile" }
      its([:float]) { should eq(0.0) }
      its([:bool_true]) { should be(true) }
      its([:bool_false]) { should be(false) }
      its([:nil]) { should be_nil }
      its([:int]) { should eq(1) }

      context "with strings as key filter values" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(string))
        end

        its(["string"]) { should eq("[FILTERED]") }
      end

      describe ":hash" do
        let(:sanitized_params) do
          described_class.sanitize(params, :filter_parameters => %w(nested_text))
        end
        subject { sanitized_params[:hash] }

        its([:nested_text]) { should eq("[FILTERED]") }

        describe ":nested_array" do
          describe ":nested_hash" do
            let(:sanitized_params) do
              described_class.sanitize(params, :filter_parameters => %w(key))
            end
            subject { sanitized_params[:hash][:nested_array][3] }

            its([:key]) { should eq("[FILTERED]") }
          end
        end
      end
    end
  end
end
