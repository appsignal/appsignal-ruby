require 'spec_helper'

describe Appsignal::EventFormatter::ActiveRecord::InstantiationFormatter do
  let(:klass)     { Appsignal::EventFormatter::ActiveRecord::SqlFormatter }
  let(:formatter) { klass.new }

  it "should register sql.active_record" do
    Appsignal::EventFormatter.registered?('sql.active_record', klass).should be_true
  end

  describe "#format" do
    let(:payload) do
      {
        name: 'User load',
        sql: 'SELECT * FROM users'
      }
    end

    subject { formatter.format(payload) }

    it { should == ['User load', 'SELECT * FROM users', 1] }
  end
end
