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
  let(:current_transaction) { background_job_transaction }
  let(:item) {{
    'class'       => 'TestClass',
    'retry_count' => 0,
    'queue'       => 'default',
    'enqueued_at' => Time.parse('01-01-2001 10:00:00UTC'),
    'args'        => ['Model', 1],
    'extra'       => 'data'
  }}
  let(:plugin) { Appsignal::Integrations::SidekiqPlugin.new }

  before do
    Appsignal.stub(:is_ignored_exception? => false)
    Appsignal::Transaction.stub(:current => current_transaction)
  end

  context "with a performance call" do
    it "should wrap in a transaction with the correct params" do
      Appsignal.should_receive(:monitor_transaction).with(
        'perform_job.sidekiq',
        :class    => 'TestClass',
        :method   => 'perform',
        :metadata => {
          'retry_count' => "0",
          'queue'       => 'default',
          'extra'       => 'data'
        },
        :params      => ['Model', "1"],
        :queue_start => Time.parse('01-01-2001 10:00:00UTC')
      )
    end

    it "reports the correct job class for a ActiveJob wrapped job" do
      item['wrapped'] = 'ActiveJobClass'
      Appsignal.should_receive(:monitor_transaction).with(
        'perform_job.sidekiq',
        :class    => 'ActiveJobClass',
        :method   => 'perform',
        :metadata => {
          'retry_count' => "0",
          'queue'       => 'default',
          'extra'       => 'data',
          'wrapped'     => 'ActiveJobClass'
        },
        :params      => ['Model', "1"],
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
      Appsignal::Transaction.any_instance.should_receive(:set_error).with(error)
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

  describe "#formatted_data" do
    let(:item) do
      {
        'foo'   => 'bar',
        'class' => 'TestClass',
      }
    end

    it "should only add items to the hash that do not appear in JOB_KEYS" do
      plugin.formatted_metadata(item).should == {'foo' => 'bar'}
    end
  end

  describe "#format_args" do
    let(:object) { Object.new }
    let(:args) do
      [
        'Model',
        1,
        object
      ]
    end

    it "should format the arguments" do
      plugin.format_args(args).should == ['Model', '1', object.inspect]
    end
  end

  describe "#truncate" do
    let(:very_long_text) do
      "a" * 400
    end

    it "should truncate the text to 200 chars max" do
      plugin.truncate(very_long_text).should == "#{'a' * 197}..."
    end
  end

  describe "#string_or_inspect" do
    context "when string" do
      it "should return the string" do
        plugin.string_or_inspect('foo').should == 'foo'
      end
    end

    context "when integer" do
      it "should return the string" do
        plugin.string_or_inspect(1).should == '1'
      end
    end

    context "when object" do
      let(:object) { Object.new }

      it "should return the string" do
        plugin.string_or_inspect(object).should == object.inspect
      end
    end

  end

  context "without sidekiq" do
    before(:all) { Object.send(:remove_const, :Sidekiq) }

    specify { expect { Sidekiq }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
