require 'spec_helper'


describe Appsignal::Hooks::ShoryukenMiddleware do

  let(:current_transaction) { background_job_transaction }

  let(:worker_instance) { double }
  let(:queue) { double }
  let(:sqs_msg) {
    double(:attributes => {})
  }
  let(:body) {{}}

  before do
    Appsignal.stub(:is_ignored_exception? => false)
    Appsignal::Transaction.stub(:current => current_transaction)
    start_agent
  end

  context "with an erroring call" do
    let(:error) { VerySpecificError.new('on fire') }
    
    it "should add the exception to appsignal" do
      Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
    end

    after do
      begin
        Timecop.freeze(Time.parse('01-01-2001 10:01:00UTC')) do
          Appsignal::Hooks::ShoryukenMiddleware.new.call(worker_instance, queue, sqs_msg, body) do
            raise error
          end
        end
      rescue VerySpecificError
      end
    end

  end

end

describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    before(:all) do
      module Shoryuken
        def self.configure_server
        end
      end
      Appsignal::Hooks::ShoryukenHook.new.install
    end

    after(:all) do
      Object.send(:remove_const, :Shoryuken)
    end

    its(:dependencies_present?) { should be_true }
  end

  context "without shoryuken" do
    its(:dependencies_present?) { should be_false }
  end
end