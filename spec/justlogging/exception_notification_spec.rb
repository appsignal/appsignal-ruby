require 'spec_helper'

describe Appsignal::ExceptionNotification do
  let(:error) { StandardError.new('moo') }
  let(:notification) { Appsignal::ExceptionNotification.new({}, error) }
  subject { notification }
  before { Rails.stub(:respond_to? => false) }

  its(:exception) { should == error }
  its(:name) { should == 'StandardError' }
  its(:message) { should == 'moo' }
end
