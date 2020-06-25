describe Appsignal::Environment do
  include EnvironmentMetadataHelper

  before(:context) { start_agent }
  before { capture_environment_metadata_report_calls }

  def report(key, &value_block)
    described_class.report(key, &value_block)
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

    context "when the value is true or false" do
      it "reports true or false as Strings" do
        logs =
          capture_logs do
            report("_test_true") { true }
            report("_test_false") { false }
            expect_environment_metadata("_test_true", "true")
            expect_environment_metadata("_test_false", "false")
          end
        expect(logs).to be_empty
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

  describe ".report_supported_gems" do
    it "reports about all AppSignal supported gems in the bundle" do
      logs = capture_logs { described_class.report_supported_gems }

      expect(logs).to be_empty

      bundle_gem_specs = ::Bundler.rubygems.all_specs
      rack_spec = bundle_gem_specs.find { |s| s.name == "rack" }
      rake_spec = bundle_gem_specs.find { |s| s.name == "rake" }
      expect_environment_metadata("ruby_rack_version", rack_spec.version.to_s)
      expect_environment_metadata("ruby_rake_version", rake_spec.version.to_s)
      expect(rack_spec.version.to_s).to_not be_empty
      expect(rake_spec.version.to_s).to_not be_empty
    end

    context "when something unforseen errors" do
      it "does not re-raise the error and writes it to the log" do
        expect(Bundler).to receive(:rubygems).and_raise(RuntimeError, "bundler error")

        logs = capture_logs { described_class.report_supported_gems }
        expect(logs).to contains_log(
          :error,
          "Unable to report supported gems:\nRuntimeError: bundler error"
        )
      end
    end
  end

  describe ".report_enabled" do
    it "reports a feature being enabled" do
      logs = capture_logs { described_class.report_enabled("a_test") }

      expect(logs).to be_empty
      expect_environment_metadata("ruby_a_test_enabled", "true")
    end

    context "when something unforseen errors" do
      it "does not re-raise the error and writes it to the log" do
        klass = Class.new do
          def to_s
            raise "to_s error"
          end
        end

        logs = capture_logs { described_class.report_enabled(klass.new) }
        expect(logs).to contains_log(
          :error,
          "Unable to report integration enabled:\nRuntimeError: to_s error"
        )
      end
    end
  end
end
