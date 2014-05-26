require 'spec_helper'

if rails_present?
  require 'action_view'
  require 'appsignal/aggregator/middleware/action_view_sanitizer'

  describe Appsignal::Aggregator::Middleware::ActionViewSanitizer do
    let(:klass) { Appsignal::Aggregator::Middleware::ActionViewSanitizer }
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
        subject[:identifier].should == 'app/views/home/index/html.erb'
      end

      context "with a frozen identifier" do
        let(:payload) do
          {
            :identifier => '/var/www/app/20130101/app/views/home/index/html.erb'.freeze
          }
        end

        it "should strip Rails root from the path" do
          subject[:identifier].should == 'app/views/home/index/html.erb'
        end
      end
    end
  end
end
