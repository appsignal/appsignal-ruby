require 'spec_helper'

describe Appsignal::ToAppsignalHash do
  subject { notification_event }

  it { should be_instance_of ActiveSupport::Notifications::Event }
  it { should respond_to(:to_appsignal_hash) }

  describe "#to_appsignal_hash" do
    subject { notification_event.to_appsignal_hash }

    it { should == {
      :time => 978364860.0,
      :duration => be_within(0.01).of(100.0),
      :end => 978364860.1,
      :name => "process_action.action_controller",
      :payload => {
        :path=>"/blog",
        :action=>"show",
        :controller=>"BlogPostsController",
        :request_format=>"html",
        :request_method=>"GET",
        :status=>"200",
        :view_runtime=>500,
        :db_runtime=>500
      }
    } }
  end
end
