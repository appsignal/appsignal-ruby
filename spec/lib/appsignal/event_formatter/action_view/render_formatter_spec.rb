describe Appsignal::EventFormatter::ActionView::RenderFormatter do
  let(:klass) { Appsignal::EventFormatter::ActionView::RenderFormatter }

  if DependencyHelper.rails_present?
    require "action_view"

    context "when in a Rails app" do
      let(:formatter) { klass.new }
      before { allow(Rails.root).to receive(:to_s).and_return("/var/www/app/20130101") }

      it "registers render_partial.action_view and render_template.action_view" do
        expect(Appsignal::EventFormatter.registered?("render_partial.action_view",
          klass)).to be_truthy
        expect(Appsignal::EventFormatter.registered?("render_template.action_view",
          klass)).to be_truthy
      end

      describe "#root_path" do
        subject { formatter.root_path }

        it "returns Rails root path" do
          is_expected.to eq "/var/www/app/20130101/"
        end
      end

      describe "#format" do
        subject { formatter.format(payload) }

        context "with an identifier" do
          let(:payload) { { :identifier => "/var/www/app/20130101/app/views/home/index/html.erb" } }

          it { is_expected.to eq ["app/views/home/index/html.erb", nil] }
        end

        context "with a frozen identifier" do
          let(:payload) do
            { :identifier => "/var/www/app/20130101/app/views/home/index/html.erb".freeze }
          end

          it { is_expected.to eq ["app/views/home/index/html.erb", nil] }
        end

        context "without an identifier" do
          let(:payload) { {} }

          it { is_expected.to be_nil }
        end
      end
    end
  else
    context "when not in a Rails app" do
      it "does not register the event formatter" do
        expect(Appsignal::EventFormatter.registered?("render_partial.action_view",
          klass)).to be_falsy
        expect(Appsignal::EventFormatter.registered?("render_template.action_view",
          klass)).to be_falsy
      end
    end
  end
end
