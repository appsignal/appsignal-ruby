require 'spec_helper'

describe Appsignal::ParamsSanitizer do
  describe ".sanitize" do
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
              :nested_array_hash_file => file,
            }
          ]
        }
      }
    end
    let(:sanitized_params) { Appsignal::ParamsSanitizer.sanitize(params) }

    subject { sanitized_params }

    it { should be_instance_of Hash }
    it('should have a text') { subject[:text].should == 'string' }
    it('should have a file') do
      subject[:file].should be_instance_of String
      subject[:file].should include '#<ActionDispatch::Http::UploadedFile:'
    end

    context "hash" do
      subject { sanitized_params[:hash] }

      it { should be_instance_of Hash }
      it('should have a nested text') { subject[:nested_text].should == 'string' }

      context "nested_array" do
        subject { sanitized_params[:hash][:nested_array] }

        it { should be_instance_of Array }

        it("should have two string items") do
          subject.first.should == 'something'
          subject.second.should == 'else'
        end
        it "should have a file" do
          subject.third.should be_instance_of String
          subject.third.should include '#<ActionDispatch::Http::UploadedFile:'
        end

        context "nested hash" do
          subject { sanitized_params[:hash][:nested_array].fourth }

          it { should be_instance_of Hash }
          it('should have a text') { subject[:key].should == 'value' }
          it('should have a file') do
            subject[:nested_array_hash_file].should be_instance_of String
            subject[:nested_array_hash_file].should include '#<ActionDispatch::Http::UploadedFile:'
          end
        end
      end
    end
  end
end
