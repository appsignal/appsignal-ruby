require 'spec_helper'

describe "Sidekiq integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/sidekiq.rb') }
  before :all do
    module Sidekiq
      def self.configure_server
      end
    end
  end
  before do
    load file
    start_agent
  end

  let(:worker) { double }
  let(:queue) { double }
  let(:current_transaction) { Appsignal::Transaction.create(SecureRandom.uuid, {}) }
  let(:item) {{
    'class' => 'TestClass',
    'retry_count' => 0,
    'queue' => 'default',
    'enqueued_at' => Time.parse('01-01-2001 10:00:00UTC')
  }}

  before do
    Appsignal.stub(:is_ignored_exception? => false)
    Appsignal::Transaction.stub(:current => current_transaction)
  end

  context "with a performance call" do
    it "should wrap in a transaction with the correct params" do
      Appsignal.should_receive(:monitor_transaction).with(
        'perform_job.sidekiq',
        :class => 'TestClass',
        :method => 'perform',
        :attempts => 0,
        :queue => 'default',
        :queue_start => Time.parse('01-01-2001 10:00:00UTC')
      )
    end

    after do
      Timecop.freeze(Time.parse('01-01-2001 10:01:00UTC')) do
        Appsignal::Integrations::SidekiqPlugin.new.call(worker, item, queue) do
          # nothing
        end
      end
    end
  end

  context "with an erroring call" do
    let(:error) { VerySpecificError.new('the roof') }
    it "should add the exception to appsignal" do
      current_transaction.should_receive(:set_exception).with(error)
    end

    after do
      begin
        Timecop.freeze(Time.parse('01-01-2001 10:01:00UTC')) do
          Appsignal::Integrations::SidekiqPlugin.new.call(worker, item, queue) do
            raise error
          end
        end
      rescue VerySpecificError
      end
    end
  end

  context "without sidekiq" do
    before(:all) { Object.send(:remove_const, :Sidekiq) }

    specify { expect { Sidekiq }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
