describe Appsignal::Hooks::DataMapperHook do
  context "with datamapper" do
    before :context do
      module DataMapper
      end

      module DataObjects
        class Connection
        end
      end
      Appsignal::Hooks::DataMapperHook.new.install
    end

    after :context do
      Object.send(:remove_const, :DataMapper)
      Object.send(:remove_const, :DataObjects)
    end

    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_truthy }
    end

    it "should install the listener" do
      expect(::DataObjects::Connection).to receive(:include)
        .with(Appsignal::Hooks::DataMapperLogListener)

      Appsignal::Hooks::DataMapperHook.new.install
    end
  end

  context "without datamapper" do
    describe "#dependencies_present?" do
      subject { described_class.new.dependencies_present? }

      it { is_expected.to be_falsy }
    end
  end
end
