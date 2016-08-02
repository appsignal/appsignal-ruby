require 'spec_helper'

describe Appsignal::Utils::ParamsSanitizer do
  let(:file) { uploaded_file }
  let(:params) do
    {
      :text       => 'string',
      :file       => file,
      :float      => 0.0,
      :bool_true  => true,
      :bool_false => false,
      :nil        => nil,
      :int        => 1,
      :hash       => {
        :nested_text  => 'string',
        :nested_array => [
          'something',
          'else',
          file,
          {
            :key  => 'value',
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
    its([:text]) { should == 'string' }
    its([:file]) { should be_instance_of String }
    its([:file]) { should include '::UploadedFile' }
    its([:float]) { should eq(0.0) }
    its([:bool_true]) { should be(true) }
    its([:bool_false]) { should be(false) }
    its([:nil]) { should be_nil }
    its([:int]) { should eq(1) }

    it "does not change the original params" do
      subject
      params[:file].should == file
      params[:hash][:nested_array][2].should == file
    end

    context "hash" do
      subject { sanitized_params[:hash] }

      it { should be_instance_of Hash }
      its([:nested_text]) { should == 'string' }

      context "nested_array" do
        subject { sanitized_params[:hash][:nested_array] }

        it { should be_instance_of Array }
        its([0]) { should == 'something' }
        its([1]) { should == 'else' }
        its([2]) { should be_instance_of String }
        its([2]) { should include '::UploadedFile' }

        context "nested hash" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == 'value' }
          its([:file]) { should be_instance_of String }
          its([:file]) { should include '::UploadedFile' }
        end
      end
    end
  end
end
