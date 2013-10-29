require 'spec_helper'

module Appsignal
  IgnoreMeError = Class.new(StandardError)
end

class AppWithError
  def self.call(env)
    raise Appsignal::IgnoreMeError, 'the roof'
  end
end

describe Appsignal::Rack::Listener do
  describe '#call' do
    let(:app) { double(:call => true) }
    let(:env) { {'action_dispatch.request_id' => '1'} }
    let(:middleware) { Appsignal::Rack::Listener.new(app, {})}
    let(:current) { double(:complete! => true, :add_exception => true) }
    before { Appsignal::Transaction.stub(:current => current) }

    describe 'around call' do
      it 'should create an appsignal transaction' do
        Appsignal::Transaction.should_receive(:create).with('1', env)
      end

      it 'should call complete! after the call' do
        current.should_receive(:complete!)
      end

      context "when not active" do
        before { Appsignal.stub(:active? => false) }

        it 'should not create an appsignal transaction' do
          Appsignal::Transaction.should_not_receive(:create)
        end
      end

      after { middleware.call(env) }
    end

    describe 'with exception' do
      let(:app) { AppWithError }

      it 'should re-raise the exception' do
        expect {
          middleware.call(env)
        }.to raise_error
      end

      it 'should catch the exception and notify the transaction of it' do
        current.should_receive(:add_exception)
        middleware.call(env) rescue nil
      end

      context 'when ignoring exception' do
        before { Appsignal.stub(:config => {:ignore_exceptions => 'Appsignal::IgnoreMeError'})}

        it 'should re-raise the exception' do
          expect {
            middleware.call(env)
          }.to raise_error
        end

        it 'should ignore the error' do
          current.should_not_receive(:add_exception)
          middleware.call(env) rescue nil
        end
      end

      describe 'after an error' do
        it 'should call complete! after the call' do
          current.should_receive(:complete!)
        end

        after { middleware.call(env) rescue nil }
      end
    end
  end
end
