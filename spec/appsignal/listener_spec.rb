require 'spec_helper'

module Appsignal
  IgnoreMeError = Class.new(StandardError)
end

class AppWithError
  def self.call(env)
    raise Appsignal::IgnoreMeError, 'the roof'
  end
end

describe Appsignal::Listener do
  describe '#call' do
    let(:app) { stub(:call => true) }
    let(:env) { {'action_dispatch.request_id' => '1'} }
    let(:middleware) { Appsignal::Listener.new(app, {})}
    let(:current) { stub(:complete! => true, :add_exception => true) }
    before { Appsignal::Transaction.stub(:current => current) }

    describe 'around call' do
      it 'should call appsignal transaction' do
        Appsignal::Transaction.should_receive(:create).with('1', env)
      end

      it 'should call complete! after the call' do
        current.should_receive(:complete!)
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
        Appsignal::ExceptionNotification.should_receive(:new)
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
          Appsignal::ExceptionNotification.should_not_receive(:new)
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
