# frozen_string_literal: true

describe Appsignal::Hooks::HttpHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  if DependencyHelper.http_present?
    context "with instrument_http_rb set to true" do
      describe "#dependencies_present?" do
        subject { described_class.new.dependencies_present? }

        it { is_expected.to be_truthy }
      end

      if DependencyHelper.http6_present?
        it "installs the HTTP plugin with keyword options" do
          expect(HTTP::Client.included_modules)
            .to include(Appsignal::Integrations::HttpIntegration::KeywordOptions)
        end
      else
        it "installs the HTTP plugin with hash options" do
          expect(HTTP::Client.included_modules)
            .to include(Appsignal::Integrations::HttpIntegration::HashOptions)
        end
      end
    end

    context "with instrument_http_rb set to false" do
      let(:options) { { :instrument_http_rb => false } }

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
