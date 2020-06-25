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

    context "when the key is a non String type" do
      it "does not set the value" do
        logs =
          capture_logs do
            report(:_test_symbol) { "1.0.0" }
            expect_not_environment_metadata(:_test_symbol)
            expect_not_environment_metadata("_test_symbol")
          end
        expect(logs).to contains_log(
          :error,
          "Unable to report on environment metadata: Unsupported value type for :_test_symbol"
        )
      end
    end

    context "when the key is nil" do
      it "does not set the value" do
        logs =
          capture_logs do
            report(nil) { "1" }
            expect_not_environment_metadata(nil)
          end
        expect(logs).to contains_log(
          :error,
          "Unable to report on environment metadata: Unsupported value type for nil"
        )
      end
    end

    context "when the value is nil" do
      it "does not set the value" do
        logs =
          capture_logs do
            report("_test_ruby_version") { nil }
            expect_not_environment_metadata("_test_ruby_version")
          end
        expect(logs).to contains_log(
          :error,
          "Unable to report on environment metadata \"_test_ruby_version\": " \
            "Unsupported value type for nil"
        )
      end
    end

    context "when the value block raises an error" do
      it "does not re-raise the error and writes it to the log" do
        logs =
          capture_logs do
            report("_test_error") { raise "uh oh" }
            expect_not_environment_metadata("_test_error")
          end
        expect(logs).to contains_log(
          :error,
          "Unable to report on environment metadata \"_test_error\":\n" \
            "RuntimeError: uh oh"
        )
      end
    end

    context "when something unforseen errors" do
      it "does not re-raise the error and writes it to the log" do
        klass = Class.new do
          def inspect
            raise "inspect error"
          end
        end

        logs =
          capture_logs do
            report(klass.new) { raise "value error" }
            expect(Appsignal::Extension).to_not have_received(:set_environment_metadata)
          end
        expect(logs).to contains_log(
          :error,
          "Unable to report on environment metadata:\n" \
            "RuntimeError: inspect error"
        )
      end
    end
  end
end
