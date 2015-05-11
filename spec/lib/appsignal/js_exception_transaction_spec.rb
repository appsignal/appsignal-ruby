require 'spec_helper'

describe Appsignal::JSExceptionTransaction do
  before { SecureRandom.stub(:uuid => '123abc') }

  let!(:transaction) { Appsignal::JSExceptionTransaction.new(data) }
  let(:data) do
    {
      'name'        => 'TypeError',
      'message'     => 'foo is not a valid method',
      'action'      => 'ExceptionIncidentComponent',
      'path'        => 'foo.bar/moo',
      'environment' => 'development',
      'backtrace'   => [
        'foo.bar/js:11:1',
        'foo.bar/js:22:2',
      ]
    }
  end

  describe "#initialize" do
    it "should call all required methods" do
      expect( Appsignal::Extension ).to receive(:start_transaction).with('123abc')

      expect( transaction ).to receive(:set_base_data)
      expect( transaction ).to receive(:set_metadata)
      expect( transaction ).to receive(:set_error)
      expect( transaction ).to receive(:set_error_data)

      transaction.send :initialize, data
    end
  end

  describe "#set_base_data" do
    it "should call `Appsignal::Extension.set_transaction_basedata`" do
      expect( Appsignal::Extension ).to receive(:set_transaction_basedata).with(
        '123abc',
        'frontend',
        'ExceptionIncidentComponent',
        0
      )

      transaction.set_base_data
    end
  end

  describe "#set_metadata" do
   it "should call `Appsignal::Extension.set_transaction_metadata`" do
     expect( Appsignal::Extension ).to receive(:set_transaction_metadata).with(
      '123abc',
       'path',
       'foo.bar/moo'
     )

     transaction.set_metadata
   end
  end

  describe "#set_error" do
   it "should call `Appsignal::Extension.set_transaction_error`" do
     expect( Appsignal::Extension ).to receive(:set_transaction_error).with(
      '123abc',
       'TypeError',
       'foo is not a valid method'
     )

     transaction.set_error
   end
  end

  describe "#set_error_data" do
   it "should call `Appsignal::Extension.set_transaction_error_data`" do
     expect( Appsignal::Extension ).to receive(:set_transaction_error_data).with(
      '123abc',
      'backtrace',
      '["foo.bar/js:11:1","foo.bar/js:22:2"]'
     )

     transaction.set_error_data
   end
  end

  describe "#complete!" do
    it "should call all required methods" do
      expect( Appsignal::Extension ).to receive(:finish_transaction).with('123abc')
      transaction.complete!
    end
  end

end
