describe Appsignal::EventFormatter::ViewComponent::RenderFormatter do
  let(:klass) { Appsignal::EventFormatter::ViewComponent::RenderFormatter }

  if DependencyHelper.rails_present?
    context "when in a Rails app" do
      let(:formatter) { klass.new }
      before { allow(Rails.root).to receive(:to_s).and_return("/var/www/app/20130101") }

      it "registers render.view_component" do
        expect(Appsignal::EventFormatter.registered?("render.view_component",
          klass)).to be_truthy
      end

      describe "#opentelemetry_attributes" do
        subject { formatter.opentelemetry_attributes({}) }

        it { is_expected.to eq("appsignal.group" => "render") }
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
    context "when not in a Rails app" do
      let(:formatter) { klass.new }

      it "registers render.view_component" do
        expect(Appsignal::EventFormatter.registered?("render.view_component",
          klass)).to be_truthy
      end

      describe "#opentelemetry_attributes" do
        subject { formatter.opentelemetry_attributes({}) }

        it "still says the event is template rendering" do
          is_expected.to eq("appsignal.group" => "render")
        end
      end

      describe "#format" do
        subject { formatter.format(payload) }

        let(:payload) do
          {
            :name => "WhateverComponent",
            :identifier => "/var/www/app/20130101/app/components/whatever_component.rb"
          }
        end

        # There is no application root to make the component's path relative to.
        it { is_expected.to be_nil }
      end
    end
  end
end
