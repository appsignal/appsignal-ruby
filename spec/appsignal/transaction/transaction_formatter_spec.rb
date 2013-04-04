require 'spec_helper'

describe Appsignal::TransactionFormatter do
  let(:klass) { Appsignal::TransactionFormatter }
  let(:formatter) { klass.new(transaction) }
  subject { formatter }
  before { transaction.stub(:fullpath => '/foo') }

  describe "#to_hash" do
    before { formatter.to_hash }
    subject { formatter.hash }

    context "with a regular request" do
      let(:transaction) { regular_transaction }

      its(:keys) { should == [:request_id, :log_entry, :failed] }
      its([:request_id]) { should == '1' }
      its([:log_entry]) { should == {
          :action => "BlogPostsController#show",
          :db_runtime => 500,
          :duration => 100.0,
          :end => 978339660.1,
          :environment => {},
          :kind => "http_request",
          :path => "/blog",
          :request_format => "html",
          :request_method => "GET",
          :session_data => {},
          :status => "200",
          :time => 978339660.0,
          :view_runtime => 500
      } }
      its([:failed]) { should be_false }
    end

    context "with an exception request" do
      let(:transaction) { transaction_with_exception }

      its(:keys) { should == [:request_id, :log_entry, :failed, :exception] }
      its([:request_id]) { should == '1' }
      its([:failed]) { should be_true }

      context "exception content" do
        subject { formatter.hash[:exception] }

        its(:keys) { should == [:backtrace, :exception, :message] }
        its([:backtrace]) { should be_instance_of Array }
        its([:exception]) { should == 'ArgumentError' }
        its([:message]) { should == 'oh no' }
      end
    end

    context "with a slow request" do
      let(:transaction) { slow_transaction }

      its(:keys) { should == [:request_id, :log_entry, :failed, :events] }
      its([:request_id]) { should == '1' }
      its([:failed]) { should be_false }

      context "events content" do
        subject { formatter.hash[:events] }

        its(:length) { should == 1 }
        its(:first) { should == {
          :name => "query.mongoid",
          :duration => 100.0,
          :time => 978339660.0,
          :end => 978339660.1,
          :payload => {
            :path => "/blog",
            :action => "show",
            :controller => "BlogPostsController",
            :request_format => "html",
            :request_method => "GET",
            :status => "200",
            :view_runtime => 500,
            :db_runtime => 500
          }
        } }
      end
    end
  end
end
