require 'spec_helper'

describe Appsignal do

  it { should respond_to :subscriber }

  describe ".transactions" do
    subject { Appsignal.transactions }

    it { should be_a Hash }
  end

  describe '.agent' do
    subject { Appsignal.agent }

    it { should be_a Appsignal::Agent }
  end

  describe '.config' do
    subject { Appsignal.config }

    it 'should return the endpoint' do
      subject[:endpoint].should eq 'http://localhost:3000/api/1'
    end

    it 'should return the api key' do
      subject[:api_key].should eq 'abc'
    end

    it 'should return ignored exceptions' do
      subject[:ignore_exceptions].should eq []
    end
  end
end
