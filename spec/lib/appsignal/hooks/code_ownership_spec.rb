describe Appsignal::Hooks::CodeOwnershipHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    if DependencyHelper.code_ownership_present?
      context "when CodeOwnership is present" do
        it { is_expected.to be_truthy }

        context "when `instrument_code_ownership` is set to false" do
          let(:options) { { :instrument_code_ownership => false } }

          it { is_expected.to be_falsey }
        end
      end
    else
      context "when CodeOwnership is not present" do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe "#install" do
    it "requires and installs the CodeOwnership integration" do
      expect(Appsignal::Transaction.before_complete).to be_empty

      described_class.new.install

      expect(Appsignal::Transaction.before_complete).to eq(Set.new([
        Appsignal::Integrations::CodeOwnershipIntegration.method(:before_complete)
      ]))
    end
  end
end
