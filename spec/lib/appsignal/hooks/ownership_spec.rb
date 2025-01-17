describe Appsignal::Hooks::OwnershipHook do
  let(:options) { {} }
  before { start_agent(:options => options) }

  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    if DependencyHelper.ownership_present?
      context "when Ownership is present" do
        it { is_expected.to be_truthy }

        context "when the version is not supported" do
          before do
            stub_const("Ownership::VERSION", "0.1.0")
          end

          it { is_expected.to be_falsey }
        end

        context "when `instrument_ownership` is set to false" do
          let(:options) { { :instrument_ownership => false } }

          it { is_expected.to be_falsey }
        end
      end
    else
      context "when Ownership is not present" do
        it { is_expected.to be_falsey }
      end
    end
  end

  describe "#install" do
    before do
      # Depending on the gemfile with which the test suite is ran, the
      # `Ownership` constant may or may not be defined as the real module.
      # We don't want this test to modify the real `Ownership` module, so we
      # stub it out regardless.
      stub_const("Ownership", Module.new)
    end

    it "requires and installs the Ownership integration" do
      expect(Appsignal::Transaction.after_create).to be_empty
      expect(Appsignal::Transaction.before_complete).to be_empty

      # Depending on which subset of the test suite is being ran, the
      # file containing `OwnershipIntegration` may or may not have been
      # required. If it's not been required, it cannot possibly have been
      # included, so it implicitly asserts that it's not been included yet.
      if defined?(Appsignal::Integrations::OwnershipIntegration)
        expect(Ownership.singleton_class.included_modules).not_to(
          include(Appsignal::Integrations::OwnershipIntegration)
        )
      end

      described_class.new.install

      expect(Appsignal::Transaction.after_create).to eq(Set.new([
        Appsignal::Integrations::OwnershipIntegrationHelper.method(:after_create)
      ]))

      expect(Appsignal::Transaction.before_complete).to eq(Set.new([
        Appsignal::Integrations::OwnershipIntegrationHelper.method(:before_complete)
      ]))

      expect(Ownership.singleton_class.included_modules).to include(
        Appsignal::Integrations::OwnershipIntegration
      )
    end
  end
end
