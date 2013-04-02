require 'spec_helper'

describe Appsignal::ParamsSanitizer do
  let(:file) { ActionDispatch::Http::UploadedFile.new(:tempfile => '/tmp') }
  let(:params) do
    {
      :text => 'string',
      :file => file,
      :hash => {
        :nested_text => 'string',
        :nested_array => [
          'something',
          'else',
          file,
          {
            :key => 'value',
            :file => file,
          }
        ]
      }
    }
  end
  let(:sanitized_params) { Appsignal::ParamsSanitizer.sanitize(params) }

  describe ".sanitize!" do
    subject { params }
    before { Appsignal::ParamsSanitizer.sanitize!(subject) }

    it { should be_instance_of Hash }
    its([:text]) { should == 'string' }
    its([:file]) { should be_instance_of String }
    its([:file]) { should include '#<ActionDispatch::Http::UploadedFile:' }

    context "hash" do
      subject { params[:hash] }

      it { should be_instance_of Hash }
      its([:nested_text]) { should == 'string' }

      context "nested_array" do
        subject { params[:hash][:nested_array] }

        it { should be_instance_of Array }
        its([0]) { should == 'something' }
        its([1]) { should == 'else' }
        its([2]) { should be_instance_of String }
        its([2]) { should include '#<ActionDispatch::Http::UploadedFile:' }

        context "nested hash" do
          subject { params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == 'value' }
          its([:file]) { should be_instance_of String }
          its([:file]) { should include '#<ActionDispatch::Http::UploadedFile:' }
        end
      end
    end
  end

  describe ".sanitize" do
    subject { sanitized_params }

    it { should be_instance_of Hash }
    its([:text]) { should == 'string' }
    its([:file]) { should be_instance_of String }
    its([:file]) { should include '#<ActionDispatch::Http::UploadedFile:' }

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
        its([2]) { should include '#<ActionDispatch::Http::UploadedFile:' }

        context "nested hash" do
          subject { sanitized_params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == 'value' }
          its([:file]) { should be_instance_of String }
          its([:file]) { should include '#<ActionDispatch::Http::UploadedFile:' }
        end
      end
    end
  end

  describe ".scrub!" do
    subject { params }
    before { Appsignal::ParamsSanitizer.scrub!(subject) }

    it { should be_instance_of Hash }
    its([:text]) { should == '?' }
    its([:file]) { should == '?' }

    context "hash" do
      subject { params[:hash] }

      it { should be_instance_of Hash }
      its([:nested_text]) { should == '?' }

      context "nested_array" do
        subject { params[:hash][:nested_array] }

        it { should be_instance_of Array }
        its([0]) { should == '?' }
        its([1]) { should == '?' }
        its([2]) { should == '?' }

        context "nested hash" do
          subject { params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == '?' }
          its([:file]) { should == '?' }
        end
      end
    end
  end
end
