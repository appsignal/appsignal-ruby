describe Appsignal::EventFormatter::ViewComponent::RenderFormatter do
  let(:klass) { Appsignal::EventFormatter::ViewComponent::RenderFormatter }

  if DependencyHelper.rails_present? && DependencyHelper.view_component_present?
    require "view_component"

    context "when in a Rails app" do
      let(:formatter) { klass.new }
      before { allow(Rails.root).to receive(:to_s).and_return("/var/www/app/20130101") }

      it "registers render.view_component and (deprecated) !render.view_component" do
        expect(Appsignal::EventFormatter.registered?("render.view_component",
          klass)).to be_truthy
        expect(Appsignal::EventFormatter.registered?("!render.view_component",
          klass)).to be_truthy
      end

      describe "#format" do
        subject { formatter.format(payload) }

        context "with a name and identifier" do
          let(:payload) do
            {
              :name => "WhateverComponent",
              :identifier => "/var/www/app/20130101/app/components/whatever_component.rb"
            }
          end

          it { is_expected.to eq ["WhateverComponent", "app/components/whatever_component.rb"] }
        end
      end
    end
  else
    context "when not in a Rails app with the ViewComponent gem" do
      it "does not register the event formatter" do
        expect(Appsignal::EventFormatter.registered?("render.view_component",
          klass)).to be_falsy
        expect(Appsignal::EventFormatter.registered?("!render.view_component",
          klass)).to be_falsy
      end
    end
  end
end
