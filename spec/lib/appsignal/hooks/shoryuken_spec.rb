require 'spec_helper'

describe Appsignal::Hooks::ShoryukenHook do
  context "with shoryuken" do
    before(:all) do
      module Shoryuken
      end
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