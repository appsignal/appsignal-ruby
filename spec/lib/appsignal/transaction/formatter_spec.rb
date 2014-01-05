require 'spec_helper'

describe Appsignal::Transaction::Formatter do
  before :all do
    start_agent
  end

  let(:klass) { Appsignal::Transaction::Formatter }
  let(:formatter) { klass.new(transaction) }
  subject { formatter }
  before { transaction.stub(:fullpath => '/foo') }

  describe "#to_hash" do
    before { formatter.to_hash }
    subject { formatter.hash }

    context "with a regular request" do
      let(:transaction) { regular_transaction }
      before { transaction.truncate! }

      its(:keys) { should =~ [:request_id, :log_entry, :failed] }
      its([:request_id]) { should == '1' }
      its([:log_entry]) { should == {
          :action => "BlogPostsController#show",
          :db_runtime => 500,
          :duration => be_within(0.01).of(100.0),
          :end => 1389783600.1,
          :environment => {},
          :kind => "http_request",
          :path => "/blog",
          :request_format => "html",
          :request_method => "GET",
          :session_data => {},
          :status => "200",
          :time => 1389783600.0,
          :view_runtime => 500
      } }
      its([:failed]) { should be_false }
    end

    context "with a regular request when queue time is present" do
      let(:transaction) { regular_transaction_with_x_request_start }
      before { transaction.truncate! }

      context "log_entry content" do
        subject { formatter.hash[:log_entry] }

        its([:queue_duration]) { should be_within(0.01).of(40.0) }
      end
    end

    context "with an exception request" do
      let(:transaction) { transaction_with_exception }

      its(:keys) { should =~ [:request_id, :log_entry, :failed, :exception] }
      its([:request_id]) { should == '1' }
      its([:failed]) { should be_true }

      context "log_entry content" do
        subject { formatter.hash[:log_entry] }

        its([:tags]) { should == {'user_id' => 123} }
      end

      context "exception content" do
        subject { formatter.hash[:exception] }

        its(:keys) { should =~ [:exception, :message, :backtrace] }
        its([:exception]) { should == 'ArgumentError' }
        its([:message]) { should == 'oh no' }

        if rails_present?
          its([:backtrace]) { should == [
            'app/controllers/somethings_controller.rb:10',
            '/user/local/ruby/path.rb:8'
          ] }
        else
          its([:backtrace]) { should == [
            File.join(project_fixture_path, 'app/controllers/somethings_controller.rb:10'),
            '/user/local/ruby/path.rb:8'
          ] }
        end
      end
    end

    context "with a slow request" do
      let(:transaction) { slow_transaction }

      its(:keys) { should =~ [:request_id, :log_entry, :failed, :events] }
      its([:request_id]) { should == '1' }
      its([:failed]) { should be_false }

      context "events content" do
        subject { formatter.hash[:events] }

        its(:length) { should == 1 }
        its(:first) { should == {
          :name => "query.mongoid",
          :duration => be_within(0.01).of(100.0),
          :time => 1389783600.0,
          :end => 1389783600.1,
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

    context "with a background request" do
      let(:payload) { create_background_payload }
      let(:transaction) { background_job_transaction({}, payload) }
      before { transaction.truncate! }

      its(:keys) { should =~ [:request_id, :log_entry, :failed] }
      its([:request_id]) { should == '1' }
      its([:log_entry]) { should == {
        :action => "BackgroundJob#perform",
        :duration => be_within(0.01).of(100.0),
        :end => 1389783600.1,
        :queue_duration => 10.0,
        :priority => 1,
        :attempts => 0,
        :queue => 'default',
        :environment => {},
        :kind => "background_job",
        :path => "/foo",
        :session_data => {},
        :time => 1389783600.0,
      } }
      its([:failed]) { should be_false }

      context "when queue_time is zero" do
        let(:payload) { create_background_payload(:queue_start => 0) }

        context "log entry" do
          subject { formatter.hash[:log_entry] }

          its([:queue_duration]) { should be_nil }
        end
      end
    end
  end
end
