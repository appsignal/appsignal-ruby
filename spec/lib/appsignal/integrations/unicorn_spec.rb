require 'spec_helper'

describe "Unicorn integration" do
  let(:file) { File.expand_path('lib/appsignal/integrations/unicorn.rb') }
  before(:all) do
    module Unicorn
      class Worker
        def close
        end
      end
    end
  end
  before do
    load file
    start_agent
  end

  it "should add behavior to Unicorn::Worker#close" do
    worker = Unicorn::Worker.new

    Appsignal.should_receive(:stop)
    worker.should_receive(:original_close)

    worker.close
  end

  context "without unicorn" do
    before(:all) { Object.send(:remove_const, :Unicorn) }

    specify { expect { Unicorn }.to raise_error(NameError) }
    specify { expect { load file }.to_not raise_error }
  end
end
