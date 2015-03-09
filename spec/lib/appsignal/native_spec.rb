require 'spec_helper'

describe Appsignal::Native do
  describe ".libappsignal_path" do
    subject { Appsignal::Native.libappsignal_path }

    it "should return the filename for the library" do
      (subject.include?('libappsignal.so') ||
       subject.include?('libappsignal.dylib')).should be_true
    end

    it "should point to an existing path" do
      File.exists?(subject).should be_true
    end
  end

  context "call native methods without errors" do
    subject { Appsignal::Native }

    it "should have a start method" do
      subject.start.should be_false
    end

    context "with a valid config" do
      before do
        project_fixture_config.write_to_environment
      end

      it "should have a start method" do
        subject.start.should be_true
      end

      it "should have a start_transaction method" do
        subject.start_transaction('request_id')
      end

      it "should have a start_event method" do
        subject.start_event('request_id')
      end

      it "should have a finish_event method" do
        subject.finish_event(
          'request_id',
          'name',
          'title',
          'body'
        )
      end

      it "should have a set_transaction_error method" do
        subject.set_transaction_error(
          'request_id',
          'name',
          'message'
        )
      end

      it "should have a set_transaction_error_data method" do
        subject.set_transaction_error_data(
          'request_id',
          'params',
          '{}'
        )
      end

      it "should have a set_transaction_basedata method" do
        subject.set_transaction_basedata(
          'request_id',
          'kind',
          'action',
          100
        )
      end

      it "should have a set_transaction_metadata method" do
        subject.set_transaction_metadata(
          'request_id',
          'key',
          'value'
        )
      end

      it "should have a finish_transaction method" do
        subject.finish_transaction('request_id')
      end

      it "should have a transmit_marker method" do
        subject.transmit_marker('{}', 'json').should == 200
      end

      it "should have a check_push_api_auth method" do
        subject.check_push_api_auth().should be_true
      end
    end
  end
end
