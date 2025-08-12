# frozen_string_literal: true

describe "Rails detection" do
  context "when Rails module exists without Railtie" do
    before do
      stub_const("Rails", Module.new)
    end

    it "does not trigger Rails integration loading" do
      expect(defined?(::Rails::Railtie)).to be_falsy
    end

    context "even with version method" do
      before do
        rails_module = Module.new do
          def self.version
            "8.0.0"
          end
        end
        stub_const("Rails", rails_module)
      end

      it "still does not trigger loading without Railtie" do
        expect(Rails.respond_to?(:version)).to be_truthy
        expect(defined?(::Rails::Railtie)).to be_falsy
      end
    end
  end

  context "when Rails::Railtie is present" do
    before do
      rails_module = Module.new do
        def self.version
          "8.0.0"
        end
      end
      stub_const("Rails", rails_module)
      stub_const("Rails::Railtie", Class.new)
    end

    it "triggers Rails integration loading" do
      expect(defined?(::Rails::Railtie)).to be_truthy
    end

    it "safely handles Rails.version" do
      expect(Rails.version).to eq("8.0.0")
    end
  end
end
