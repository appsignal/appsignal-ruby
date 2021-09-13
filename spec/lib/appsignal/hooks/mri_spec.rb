describe Appsignal::Hooks::MriHook do
  describe "#dependencies_present?" do
    subject { described_class.new.dependencies_present? }

    if DependencyHelper.running_jruby?
      it { is_expected.to be_falsy }
    else
      it { is_expected.to be_truthy }
    end
  end

  unless DependencyHelper.running_jruby?
    context "install" do
      before do
        Appsignal::Hooks.load_hooks
      end

      it "should be added to minutely probes" do
        expect(Appsignal::Minutely.probes[:mri]).to be Appsignal::Probes::MriProbe
      end
    end
  end
end
