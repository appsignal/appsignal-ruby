require 'spec_helper'

describe Appsignal::Extension do
  context "call native methods without errors" do
    subject { Appsignal::Extension }

    it "should have a start method" do
      subject.start
    end

    context "with a valid config" do
      before do
        project_fixture_config.write_to_environment
      end

      it "should have a start method" do
        subject.start
      end

      it "should have a start_transaction method" do
        subject.start_transaction('request_id')
      end

      it "should have a start_event method" do
        subject.start_event(1)
      end

      it "should have a finish_event method" do
        subject.finish_event(
          1,
          'name',
          'title',
          'body'
        )
      end

      it "should have a set_transaction_error method" do
        subject.set_transaction_error(
          1,
          'name',
          'message'
        )
      end

      it "should have a set_transaction_error_data method" do
        subject.set_transaction_error_data(
          1,
          'params',
          '{}'
        )
      end

      it "should have a set_transaction_base_data method" do
        subject.set_transaction_base_data(
          1,
          'kind',
          'action',
          100
        )
      end

      it "should have a set_transaction_metadata method" do
        subject.set_transaction_metadata(
          1,
          'key',
          'value'
        )
      end

      it "should have a finish_transaction method" do
        subject.finish_transaction(1)
      end

      it "should have a set_gauge method" do
        Appsignal.set_gauge('key', 1.0)
      end

      it "should have a set_host_gauge method" do
        Appsignal.set_host_gauge('key', 1.0)
      end

      it "should have a set_process_gauge method" do
        Appsignal.set_process_gauge('key', 1.0)
      end

      it "should have a increment_counter method" do
        Appsignal.increment_counter('key', 1)
      end

      it "should have a add_distribution_value method" do
        Appsignal.add_distribution_value('key', 1.0)
      end
    end
  end
end
