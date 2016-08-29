require 'spec_helper'

describe Appsignal::Hooks::DataMapperHook do
  context "with datamapper" do
    before :all do
      module DataMapper
      end
      module DataObjects
        class Connection
        end
      end
      Appsignal::Hooks::DataMapperHook.new.install
    end

    after :all do
      Object.send(:remove_const, :DataMapper)
      Object.send(:remove_const, :DataObjects)
    end

    its(:dependencies_present?) { should be_true }

    it "should install the listener" do
      expect(::DataObjects::Connection).to receive(:include)
        .with(Appsignal::Hooks::DataMapperLogListener)

      Appsignal::Hooks::DataMapperHook.new.install
    end
  end

  context "without datamapper" do
    its(:dependencies_present?) { should be_false }
  end
end
