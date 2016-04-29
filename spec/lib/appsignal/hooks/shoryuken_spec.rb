require 'spec_helper'

describe Appsignal::Hooks::ShoryukenHook do
  # context "with shoryuken" do
  # end

  context "without shoryuken" do
    its(:dependencies_present?) { should be_false }
  end
end