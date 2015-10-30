require 'spec_helper'
require 'fileutils'

describe "extension loading and operation" do
  describe ".agent_config" do
    subject { Appsignal::Extension.agent_config }

    it { should have_key(:version) }
    it { should have_key(:triples) }
  end

  describe ".agent_version" do
    subject { Appsignal::Extension.agent_version }

    it { should_not be_nil }
  end

  context "when the extension library can be loaded" do
    subject { Appsignal::Extension }

    it "should load the extension" do
      Appsignal.extension_loaded?.should be_true
    end

    it "should have a start and stop method" do
      subject.start
      subject.stop
    end

    context "with a valid config" do
      before do
        project_fixture_config.write_to_environment
      end

      it "should have a start and stop method" do
        subject.start
        subject.stop
      end

      it "should have a start_transaction method" do
        subject.start_transaction('request_id', 'http_request')
      end

      it "should have a start_event method" do
        subject.start_event(1)
      end

      it "should have a finish_event method" do
        subject.finish_event(1, 'name', 'title', 'body')
      end

      it "should have a set_transaction_error method" do
        subject.set_transaction_error(1, 'name', 'message')
      end

      it "should have a set_transaction_error_data method" do
        subject.set_transaction_error_data(1, 'params', '{}')
      end

      it "should have a set_transaction_action method" do
        subject.set_transaction_action(1, 'value')
      end

      it "should have a set_transaction_queue_start method" do
        subject.set_transaction_queue_start(1, 10)
      end

      it "should have a set_transaction_metadata method" do
        subject.set_transaction_metadata(1, 'key', 'value')
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
