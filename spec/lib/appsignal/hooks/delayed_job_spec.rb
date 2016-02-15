require 'spec_helper'

describe Appsignal::Hooks::DelayedJobHook do
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
    after(:all) { Object.send(:remove_const, :Delayed) }
    before do
      start_agent
    end

    its(:dependencies_present?) { should be_true }

    # We haven't found a way to test the hooks, we'll have to do that manually

    describe ".invoke_with_instrumentation" do
      let(:plugin) { Appsignal::Hooks::DelayedJobPlugin }
      let(:time) { Time.parse('01-01-2001 10:01:00UTC') }
      let(:job_data) do
        {
          :id             => 123,
          :name           => 'TestClass#perform',
          :priority       => 1,
          :attempts       => 1,
          :queue          => 'default',
          :created_at     => time - 60_000,
          :payload_object => double(:args => ['argument']),
        }
      end
      let(:job) { double(job_data) }
      let(:invoked_block) { Proc.new { } }
      let(:error) { StandardError.new }

      context "with a normal call" do
        it "should wrap in a transaction with the correct params" do
          Appsignal.should_receive(:monitor_transaction).with(
            'perform_job.delayed_job',
            :class    => 'TestClass',
            :method   => 'perform',
            :metadata => {
              :priority => 1,
              :attempts => 1,
              :queue    => 'default',
              :id       => '123'
            },
            :params      => ['argument'],
            :queue_start => time - 60_000,
          )

          Timecop.freeze(time) do
            plugin.invoke_with_instrumentation(job, invoked_block)
          end
        end

        context "with custom name call" do
          let(:job_data) do
            {
              :payload_object => double(
                :appsignal_name => 'CustomClass#perform',
                :args           => ['argument']
              ),
              :id         => '123',
              :name       => 'TestClass#perform',
              :priority   => 1,
              :attempts   => 1,
              :queue      => 'default',
              :created_at => time - 60_000
            }
          end
          it "should wrap in a transaction with the correct params" do
            Appsignal.should_receive(:monitor_transaction).with(
              'perform_job.delayed_job',
              :class => 'CustomClass',
              :method => 'perform',
              :metadata => {
                :priority => 1,
                :attempts => 1,
                :queue    => 'default',
                :id       => '123'
              },
              :params      => ['argument'],
              :queue_start => time - 60_000
            )

            Timecop.freeze(time) do
              plugin.invoke_with_instrumentation(job, invoked_block)
            end
          end
        end

        if active_job_present?
          require 'active_job'

          context "when wrapped by ActiveJob" do
            before do
              job_data[:args] = ['argument']
            end
            let(:job) { ActiveJob::QueueAdapters::DelayedJobAdapter::JobWrapper.new(job_data) }

            it "should wrap in a transaction with the correct params" do
              Appsignal.should_receive(:monitor_transaction).with(
                'perform_job.delayed_job',
                :class    => 'TestClass',
                :method   => 'perform',
                :metadata => {
                  :priority => 1,
                  :attempts => 1,
                  :queue    => 'default',
                  :id       => '123'
                },
                :params      => ['argument'],
                :queue_start => time - 60_000,
              )

              Timecop.freeze(time) do
                plugin.invoke_with_instrumentation(job, invoked_block)
              end
            end
          end
        end
      end

      context "with an erroring call" do
        it "should add the error to the transaction" do
          Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
          Appsignal::Transaction.should_receive(:complete_current!)

          invoked_block.stub(:call).and_raise(error)

          lambda {
            plugin.invoke_with_instrumentation(job, invoked_block)
          }.should raise_error(StandardError)
        end
      end
    end

    it "should add the plugin" do
      ::Delayed::Worker.plugins.should include Appsignal::Hooks::DelayedJobPlugin
    end
  end

  context "without delayed job" do
    its(:dependencies_present?) { should be_false }
  end
end
