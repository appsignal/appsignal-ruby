require 'spec_helper'

describe Appsignal::Hooks::PumaHook do
  context "with puma" do
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
    after(:all) { Object.send(:remove_const, :Puma) }

    its(:dependencies_present?) { should be_true }

    context "with a nil before worker shutdown" do
      before do
        Puma.cli_config.options.delete(:before_worker_shutdown)
        Appsignal::Hooks::PumaHook.new.install
      end

      it "should add a before shutdown worker callback" do
        Puma.cli_config.options[:before_worker_shutdown].first.should be_a(Proc)
      end
    end

    context "with an existing before worker shutdown" do
      before do
        Puma.cli_config.options[:before_worker_shutdown] = []
        Appsignal::Hooks::PumaHook.new.install
      end

      it "should add a before shutdown worker callback" do
        Puma.cli_config.options[:before_worker_shutdown].first.should be_a(Proc)
      end
    end
  end

  context "without puma" do
    its(:dependencies_present?) { should be_false }
  end
end
