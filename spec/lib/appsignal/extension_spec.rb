require 'fileutils'

describe "extension loading and operation" do
  describe ".agent_config" do
    subject { Appsignal::Extension.agent_config }

    it { should have_key('version') }
    it { should have_key('triples') }
  end

  describe ".agent_version" do
    subject { Appsignal::Extension.agent_version }

    it { should_not be_nil }
  end

  context "when the extension library can be loaded" do
    subject { Appsignal::Extension }

    it "should indicate that the extension is loaded" do
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

      context "with a transaction" do
        subject { Appsignal::Extension.start_transaction('request_id', 'http_request', 0) }

        it "should have a start_event method" do
          subject.start_event(0)
        end

        it "should have a finish_event method" do
          subject.finish_event('name', 'title', 'body', 0, 0)
        end

        it "should have a record_event method" do
          subject.record_event('name', 'title', 'body', 1000, 0, 1000)
        end

        it "should have a set_error method" do
          subject.set_error('name', 'message', '[backtrace]')
        end

        it "should have a set_sample_data method" do
          subject.set_sample_data('params', '{}')
        end

        it "should have a set_action method" do
          subject.set_action('value')
        end

        it "should have a set_queue_start method" do
          subject.set_queue_start(10)
        end

        it "should have a set_metadata method" do
          subject.set_metadata('key', 'value')
        end

        it "should have a finish method" do
          subject.finish(0)
        end

        it "should have a complete method" do
          subject.complete
        end
      end

      it "should have a set_gauge method" do
        subject.set_gauge('key', 1.0)
      end

      it "should have a increment_counter method" do
        subject.increment_counter('key', 1)
      end

      it "should have a add_distribution_value method" do
        subject.add_distribution_value('key', 1.0)
      end
    end
  end

  context "when the extension library cannot be loaded" do
    subject { Appsignal::Extension }

    before :all do
      Appsignal.extension_loaded = false
    end
    after :all do
      Appsignal.extension_loaded = true
    end

    it "should indicate that the extension is not loaded" do
      Appsignal.extension_loaded?.should be_false
    end

    it "should not raise errors when methods are called" do
      expect {
        subject.something
      }.not_to raise_error
    end
  end
end
