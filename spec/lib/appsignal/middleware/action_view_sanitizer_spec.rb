require 'spec_helper'

if rails_present?
  describe Appsignal::Middleware::ActionViewSanitizer do
    let(:klass) { Appsignal::Middleware::ActionViewSanitizer }
    let(:sanitizer) { klass.new }

    describe "#call" do
      before { Rails.root.stub(:to_s => '/var/www/app/20130101') }
      let(:event) do
        notification_event(
          :name => 'render_partial.action_view',
          :payload => create_payload(payload)
        )
      end
      let(:payload) do
        {
          :identifier => '/var/www/app/20130101/app/views/home/index/html.erb'
        }
      end
      subject { event.payload }
      before { sanitizer.call(event) { } }

      it "should strip Rails root from the path" do
        payload[:identifier].should == 'app/views/home/index/html.erb'
      end
    end
  end
end
