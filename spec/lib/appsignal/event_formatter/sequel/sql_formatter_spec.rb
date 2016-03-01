require 'spec_helper'

describe Appsignal::EventFormatter::Sequel::SqlFormatter do
  let(:klass)     { Appsignal::EventFormatter::Sequel::SqlFormatter }
  let(:formatter) { klass.new }

  it "should register sql.sequel" do
    Appsignal::EventFormatter.registered?('sql.sequel', klass).should be_true
  end

  describe "#format" do
    let(:payload) do
      {
        sql: 'SELECT * FROM users'
      }
    end

    subject { formatter.format(payload) }

    it { should == [nil, 'SELECT * FROM users', 1] }
  end
end
