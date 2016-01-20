require 'spec_helper'

describe Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter do
  let(:klass)     { Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter }
  let(:formatter) { klass.new }

  it "should register request.net_http" do
    Appsignal::EventFormatter.registered?('instantiation.active_record', klass).should be_true
  end

  describe "#format" do
    let(:payload) do
      {
        record_count: 1,
        class_name: 'User'
      }
    end

    subject { formatter.format(payload) }

    it { should == ['User', nil] }
  end
end
