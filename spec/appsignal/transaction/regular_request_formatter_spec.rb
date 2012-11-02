require 'spec_helper'

describe Appsignal::TransactionFormatter::RegularRequestFormatter do
  let(:parent) { Appsignal::TransactionFormatter }
  let(:transaction) { appsignal_transaction }
  let(:klass) { parent::RegularRequestFormatter }
  let(:regular) { klass.new(transaction) }

  describe "#sanitized_event_payload" do
    subject { regular.sanitized_event_payload(:whatever, :arguments) }

    it { should == {} }
  end
end
