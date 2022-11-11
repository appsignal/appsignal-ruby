# frozen_string_literal: true

describe Appsignal::Hooks::HttpHook do
  before :context do
    start_agent
  end

  if DependencyHelper.http_present?
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "installs the HTTP plugin" do
      expect(HTTP::Client.included_modules)
        .to include(Appsignal::Integrations::HttpIntegration)
    end
  else
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
