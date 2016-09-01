require 'spec_helper'

if rails_present?
  require 'action_view'

  describe Appsignal::EventFormatter::ActionView::RenderFormatter do
    before { Rails.root.stub(:to_s => '/var/www/app/20130101') }
    let(:klass) { Appsignal::EventFormatter::ActionView::RenderFormatter }
    let(:formatter) { klass.new }

    it "should register render_partial.action_view and render_template.action_view" do
      Appsignal::EventFormatter.registered?('render_partial.action_view', klass).should be_true
      Appsignal::EventFormatter.registered?('render_template.action_view', klass).should be_true
    end

    describe "#root_path" do
      its(:root_path) { should eq '/var/www/app/20130101/' }
    end

    describe "#format" do
      subject { formatter.format(payload) }

      context "with an identifier" do
        let(:payload) { {:identifier => '/var/www/app/20130101/app/views/home/index/html.erb'} }

        it { should eq ['app/views/home/index/html.erb', nil] }
      end

      context "with a frozen identifier" do
        let(:payload) { {:identifier => '/var/www/app/20130101/app/views/home/index/html.erb'.freeze} }

        it { should eq ['app/views/home/index/html.erb', nil] }
      end

      context "without an identifier" do
        let(:payload) { {} }

        it { should be_nil }
      end
    end
  end
end
