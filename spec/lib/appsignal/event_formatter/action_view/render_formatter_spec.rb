if DependencyHelper.rails_present?
  require "action_view"

  describe Appsignal::EventFormatter::ActionView::RenderFormatter do
    before { allow(Rails.root).to receive(:to_s).and_return("/var/www/app/20130101") }
    let(:klass) { Appsignal::EventFormatter::ActionView::RenderFormatter }
    let(:formatter) { klass.new }

    it "should register render_partial.action_view and render_template.action_view" do
      expect(Appsignal::EventFormatter.registered?("render_partial.action_view", klass)).to be_truthy
      expect(Appsignal::EventFormatter.registered?("render_template.action_view", klass)).to be_truthy
    end

    describe "#root_path" do
      describe '#root_path' do
        subject { super().root_path }
        it { is_expected.to eq "/var/www/app/20130101/" }
      end
    end

    describe "#format" do
      subject { formatter.format(payload) }

      context "with an identifier" do
        let(:payload) { { :identifier => "/var/www/app/20130101/app/views/home/index/html.erb" } }

        it { is_expected.to eq ["app/views/home/index/html.erb", nil] }
      end

      context "with a frozen identifier" do
        let(:payload) { { :identifier => "/var/www/app/20130101/app/views/home/index/html.erb".freeze } }

        it { is_expected.to eq ["app/views/home/index/html.erb", nil] }
      end

      context "without an identifier" do
        let(:payload) { {} }

        it { is_expected.to be_nil }
      end
    end
  end
end
