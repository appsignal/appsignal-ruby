# frozen_string_literal: true

describe Appsignal::Backends do
  describe ".logger" do
    context "when no config is loaded" do
      before { allow(Appsignal).to receive(:config).and_return(nil) }

      it "returns the extension backend" do
        expect(described_class.logger).to eq(Appsignal::Logger::ExtensionBackend)
      end
    end

    context "when collector mode is not active" do
      before do
        config = instance_double(Appsignal::Config, :collector_mode? => false)
        allow(Appsignal).to receive(:config).and_return(config)
      end

      it "returns the extension backend" do
        expect(described_class.logger).to eq(Appsignal::Logger::ExtensionBackend)
      end
    end

    context "when collector mode is active" do
      before do
        config = instance_double(Appsignal::Config, :collector_mode? => true)
        allow(Appsignal).to receive(:config).and_return(config)
      end

      it "returns the OpenTelemetry backend" do
        expect(described_class.logger).to eq(Appsignal::Logger::OpenTelemetryBackend)
      end
    end
  end
end
