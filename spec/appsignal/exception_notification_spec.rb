require 'spec_helper'

describe Appsignal::ExceptionNotification do
  let(:error) { StandardError.new('moo') }
  let(:notification) { Appsignal::ExceptionNotification.new({}, error, false) }
  subject { notification }
  before do
    Rails.stub(:root => '/home/app/current')
  end

  its(:env) { should == {} }
  its(:exception) { should == error }
  its(:name) { should == 'StandardError' }
  its(:message) { should == 'moo' }

  context "backtrace" do
    let(:backtrace) do
      [
        '/home/app/current/app/controllers/somethings_controller.rb:10',
        '/user/local/ruby/path.rb:8'
      ]
    end
    before { error.stub(:backtrace => backtrace) }

    subject { notification.backtrace }

    it { should == backtrace }

    context "when running the backtrace cleaner" do
      let(:notification) { Appsignal::ExceptionNotification.new({}, error) }

      it { should == [
        'app/controllers/somethings_controller.rb:10',
        '/user/local/ruby/path.rb:8'
      ] }
    end
  end
end
