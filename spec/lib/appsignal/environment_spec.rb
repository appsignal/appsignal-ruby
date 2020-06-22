describe Appsignal::Environment do
  before(:context) { start_agent }
  before do
    allow(Appsignal::Extension).to receive(:set_environment_metadata)
      .and_call_original
  end

  def report(key, &value_block)
    described_class.report(key, &value_block)
  end

  def expect_environment_metadata(key, value)
    expect(Appsignal::Extension).to have_received(:set_environment_metadata)
      .with(key, value)
  end

  def expect_not_environment_metadata(key)
    expect(Appsignal::Extension).to_not have_received(:set_environment_metadata)
      .with(key, anything)
  end

  describe ".report" do
    it "sends environment metadata to the extension" do
      logs =
        capture_logs do
          report("_test_ruby_version") { "1.0.0" }
          expect_environment_metadata("_test_ruby_version", "1.0.0")
        end
      expect(logs).to be_empty
    end

    context "when the value is nil" do
      it "does not set the value" do
        logs =
          capture_logs do
            report("_test_ruby_version") { nil }
            expect_not_environment_metadata("_test_ruby_version")
          end
        expect(logs).to contains_log(
          :warn,
          "Unable to report on environment metadata `_test_ruby_version`: Value is nil"
        )
      end
    end

    context "when the value block raises an error" do
      it "does not re-raise the error and writes it to the log" do
        logs =
          capture_logs do
            report("_test_ruby_version") { raise "uh oh" }
            expect_not_environment_metadata("_test_ruby_version")
          end
        expect(logs).to contains_log(
          :warn,
          "Unable to report on environment metadata `_test_ruby_version`: uh oh"
        )
      end
    end
  end
end
