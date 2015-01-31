require 'spec_helper'

describe "Delayed Job integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/delayed_job.rb') }

  context "with delayed job" do
    before(:all) do
      module Delayed
        class Plugin
          def self.callbacks
          end
        end

        class Worker
          def self.plugins
            @plugins ||= []
          end
        end
      end
    end
    before do
      load file
      start_agent
    end

    # We haven't found a way to test the hooks, we'll have to do that manually

    describe ".invoke_with_instrumentation" do
      let(:plugin) { Appsignal::Integrations::DelayedPlugin }
      let(:time) { Time.parse('01-01-2001 10:01:00UTC') }
      let(:job) do
        double(
          :name => 'TestClass#perform',
          :priority => 1,
          :attempts => 1,
          :queue => 'default',
          :created_at => time - 60_000
        )
      end
      let(:invoked_block) { Proc.new { } }
      let(:error) { StandardError.new }

      context "with a normal call" do
        it "should wrap in a transaction with the correct params" do
          Appsignal.should_receive(:monitor_transaction).with(
            'perform_job.delayed_job',
            :class => 'TestClass',
            :method => 'perform',
            :priority => 1,
            :attempts => 1,
            :queue => 'default',
            :queue_start => time - 60_000
          )

          Timecop.freeze(time) do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end
        end
      end

      context "with an erroring call" do
        it "should add the error to the transaction" do
          Appsignal::Transaction.any_instance.should_receive(:set_exception).with(error)
          invoked_block.stub(:call).and_raise(error)
          Appsignal::Transaction.any_instance.should_receive(:complete!)

          lambda {
            plugin.invoke_with_instrumentation(job, invoked_block)
          }.should raise_error(StandardError)
        end
      end
    end

    it "should add the plugin" do
      ::Delayed::Worker.plugins.should include Appsignal::Integrations::DelayedPlugin
    end
  end

  context "without delayed job" do
    before(:all) { Object.send(:remove_const, :Delayed) }

    specify { expect { ::Delayed }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
