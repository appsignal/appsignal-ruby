require 'spec_helper'

describe "Puma integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/puma.rb') }
  before(:all) do
    class Puma
      def self.cli_config
        @cli_config ||= CliConfig.new
      end
    end

    class CliConfig
      attr_accessor :options

      def initialize
        @options = {}
      end
    end
  end
  before do
    start_agent
  end

  context "with a nil before worker shutdown" do
    before do
      Puma.cli_config.options.delete(:before_worker_shutdown)
      load file
    end

    it "should add a before shutdown worker callback" do
      Puma.cli_config.options[:before_worker_shutdown].first.should be_a(Proc)
    end
  end

  context "with an existing before worker shutdown" do
    before do
      Puma.cli_config.options[:before_worker_shutdown] = []
      load file
    end

    it "should add a before shutdown worker callback" do
      Puma.cli_config.options[:before_worker_shutdown].first.should be_a(Proc)
    end
  end

  context "without Puma" do
    before(:all) { Object.send(:remove_const, :Puma) }

    specify { expect { Puma }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
