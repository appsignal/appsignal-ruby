require 'spec_helper'

class ErrorOnInspect
  def inspect
    raise 'Error'
  end
end

class ClassWithInspect
  def inspect
    "#<ClassWithInspect foo=\"bar\"/>"
  end
end

describe Appsignal::ParamsSanitizer do
  let(:klass) { Appsignal::ParamsSanitizer }
  let(:file) { uploaded_file }
  let(:params) do
    {
      :text => 'string',
      :file => file,
      :float => 0.0,
      :int => 1,
      :hash => {
        :nested_text => 'string',
        :nested_array => [
          'something',
          'else',
          file,
          {
            :key => 'value',
            :file => file,
          },
          ErrorOnInspect.new,
          ClassWithInspect.new
        ]
      }
    }
  end
  let(:sanitized_params) { klass.sanitize(params) }
  let(:scrubbed_params)  { klass.scrub(params) }

  describe ".sanitize!" do
    subject { params }
    before { klass.sanitize!(subject) }

    it { should be_instance_of Hash }
    its([:text])  { should == 'string' }
    its([:file])  { should be_instance_of String }
    its([:file])  { should include '::UploadedFile' }
    its([:float]) { should == 0.0 }
    its([:int])   { should == 1 }

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
        its([2]) { should include '::UploadedFile' }
        its([4]) { should == '#<ErrorOnInspect>' }
        its([5]) { should == '#<ClassWithInspect>' }

        context "nested hash" do
          subject { params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == 'value' }
          its([:file]) { should be_instance_of String }
          its([:file]) { should include '::UploadedFile' }
        end
      end
    end
  end

  describe ".sanitize" do
    subject { sanitized_params }

    it { should be_instance_of Hash }
    its([:text]) { should == 'string' }
    its([:file]) { should be_instance_of String }
    its([:file]) { should include '::UploadedFile' }

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

  describe ".scrub!" do
    subject { params }
    before { klass.scrub!(subject) }

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

  describe ".scrub" do
    subject { scrubbed_params }

     it "does not change the original params" do
      subject
      params[:file].should == file
      params[:hash][:nested_array][2].should == file
    end

    it { should be_instance_of Hash }
    its([:text]) { should == '?' }
    its([:file]) { should == '?' }

    context "hash" do
      subject { scrubbed_params[:hash] }

      it { should be_instance_of Hash }
      its([:nested_text]) { should == '?' }

      context "nested_array" do
        subject { scrubbed_params[:hash][:nested_array] }

        it { should be_instance_of Array }
        its([0]) { should == '?' }
        its([1]) { should == '?' }
        its([2]) { should == '?' }

        context "nested hash" do
          subject { scrubbed_params[:hash][:nested_array][3] }

          it { should be_instance_of Hash }
          its([:key]) { should == '?' }
          its([:file]) { should == '?' }
        end
      end
    end
  end
end
