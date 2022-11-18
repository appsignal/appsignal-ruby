# frozen_string_literal: true

describe Appsignal::Hooks::HttpHook do
  before :context do
    start_agent
  end

  if DependencyHelper.http_present?
    context "with instrument_http_rb set to true" do
      describe "#dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_truthy }
      end

      it "installs the HTTP plugin" do
        expect(HTTP::Client.included_modules)
          .to include(Appsignal::Integrations::HttpIntegration)
      end
    end

    context "with instrument_http_rb set to false" do
      before { Appsignal.config.config_hash[:instrument_http_rb] = false }
      after { Appsignal.config.config_hash[:instrument_http_rb] = true }

      describe "#dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_falsy }
      end
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
